# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Engine::ES;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Search::Object',
);

=head1 NAME

Kernel::System::Search::Object::Engine::ES - common base backend functions for specified object

=head1 DESCRIPTION

This module defines schema and rules for specified object to be used
for fallback or separate engine.

=head1 PUBLIC INTERFACE

=cut

=head2 DefaultFulltextQueryBuild()

builds fulltext query based on specific index parameter

    my $Query = $SearchEngineESObject->DefaultFulltextQueryBuild(
        Query => $Query,                                                                        # target query that appending operation will process
        AppendIntoQuery => 1,                                                                   # append query that was built into another query
        EngineObject => $Param{EngineObject},
        MappingObject => $Param{MappingObject},
        Fulltext => $Fulltext,                                                                  # fulltext parameter
        EntitiesPathMapping => {                                                                # needed mapping between objects
            Ticket => {
                Path => '',
                FieldBuildPrefix => '',
                Nested => 0,
            },
            Article => {
                Path => 'Articles',
                FieldBuildPrefix => 'Articles.',
                Nested => 1,
            },
            Attachment => {
                Path => 'Articles.Attachments',
                FieldBuildPrefix => 'Articles.Attachments.',
                Nested => 1,
            }
        },
        DefaultFields => $ConfigObject->Get('SearchEngine::ES::TicketSearchFields')->{Fulltext}, # default fields if not present in Fulltext parameter
        Simple => 0,                                                                             # decide if index is one or multi leveled (regarding nesting of objects)
    );

=cut

sub DefaultFulltextQueryBuild {
    my ( $Self, %Param ) = @_;

    my $LogObject         = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');

    return { Success => 2 } if !defined $Param{Fulltext};

    NEEDED:
    for my $Needed (qw( EntitiesPathMapping DefaultFields Simple)) {

        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return {
            Success => 0
        };
    }

    my $Query;
    my $FulltextValue;
    my $FulltextHighlight;
    my $FulltextFields;
    my $FulltextQueryOperator = 'AND';
    my $StatementOperator     = 'OR';
    my $DefaultFields         = $Param{DefaultFields};
    my $Fulltext              = $Param{Fulltext};
    my $IndexName             = $Self->{Config}->{IndexName};
    my %EntitiesPathMapping   = %{ $Param{EntitiesPathMapping} };
    my %Data                  = map { $_ => {} } keys %EntitiesPathMapping;

    if ( ref $Fulltext eq 'HASH' && $Fulltext->{Text} ) {
        $FulltextValue         = $Fulltext->{Text};
        $FulltextQueryOperator = $Fulltext->{QueryOperator}
            if $Fulltext->{QueryOperator};
        $StatementOperator = $Fulltext->{StatementOperator}
            if $Fulltext->{StatementOperator};
        $FulltextHighlight = $Fulltext->{Highlight};
        $FulltextFields    = $Fulltext->{Fields};
    }
    else {
        $FulltextValue = $Fulltext;
    }
    if ( IsArrayRefWithData($FulltextValue) ) {
        $FulltextValue = join " $StatementOperator ", @{$FulltextValue};
    }
    if ( defined $FulltextValue )
    {
        my @FulltextQuery;
        my @FulltextHighlightFieldsValid;

        # check validity of highlight fields
        if ( IsArrayRefWithData($FulltextHighlight) ) {
            for my $Property ( @{$FulltextHighlight} ) {
                my %Field = $SearchChildObject->ValidFieldsPrepare(
                    Fields => [$Property],
                    Object => $Self->{Config}->{IndexName},
                );

                FIELD:
                for my $Entity ( sort keys %Field ) {
                    next FIELD if !IsHashRefWithData( $Field{$Entity} );
                    push @FulltextHighlightFieldsValid, $Property;
                    last FIELD;
                }
            }
        }

        my $FulltextSearchFields = $FulltextFields || $DefaultFields;

        if ( !IsHashRefWithData($FulltextSearchFields) ) {
            $LogObject->Log(
                Priority => 'error',
                Message =>
                    "No fulltext search fields specified to search inside index: \"$Self->{Config}->{IndexName}\"!",
            );

            return { Success => 0 };
        }

        my @FulltextIndexFields;
        my %FulltextFieldsValid;

        for my $Entity ( sort keys %{$FulltextSearchFields} ) {
            if ( defined $EntitiesPathMapping{$Entity} && IsArrayRefWithData( $FulltextSearchFields->{$Entity} ) ) {
                $Data{$Entity}->{FulltextFields} = [];

                for my $Property ( @{ $FulltextSearchFields->{$Entity} } ) {
                    my $FulltextField = $Param{MappingObject}->FulltextSearchableFieldBuild(
                        Index  => $IndexName,
                        Entity => $Entity,
                        Field  => $Property,
                        Simple => $Param{Simple},
                    );

                    if ($FulltextField) {
                        my $Field = $EntitiesPathMapping{$Entity}->{FieldBuildPrefix} . $FulltextField;
                        push @{ $Data{$Entity}->{FulltextFields} }, $Field;
                        $FulltextFieldsValid{"${Entity}_${Property}"} = $Field;
                    }
                    else {
                        $LogObject->Log(
                            Priority => 'error',
                            Message =>
                                "Invalid fulltext search field: \"${Entity}_${Property}\" specified! (index: \"$Self->{Config}->{IndexName}\"!)",
                        );
                        return {
                            Success => 0,
                        };
                    }
                }
            }
        }

        # build highlight query
        my @HighlightQueryFields;
        for my $HighlightField (@FulltextHighlightFieldsValid) {
            if ( !$FulltextFieldsValid{$HighlightField} ) {
                $LogObject->Log(
                    Priority => 'error',
                    Message =>
                        "Invalid fulltext highlight search field: \"$HighlightField\" specified! (index: \"$Self->{Config}->{IndexName}\"!)",
                );
                return {
                    Success => 0
                };
            }
            push @HighlightQueryFields, {
                $FulltextFieldsValid{$HighlightField} => {},
            };
        }

        # clean special characters
        $FulltextValue = $Param{EngineObject}->QueryStringReservedCharactersClean(
            String => $FulltextValue,
        );

        for my $Entity ( sort keys %Data ) {
            if ( IsArrayRefWithData( $Data{$Entity}->{FulltextFields} ) ) {
                my $BaseQuery = {
                    query_string => {
                        fields           => $Data{$Entity}->{FulltextFields},
                        query            => "*$FulltextValue*",
                        default_operator => $FulltextQueryOperator,
                    }
                };

                if ( !$EntitiesPathMapping{$Entity}->{Nested} ) {
                    push @FulltextQuery, $BaseQuery;
                }
                else {
                    push @FulltextQuery, {
                        nested => {
                            path => [
                                $EntitiesPathMapping{$Entity}->{Path}
                            ],
                            query => $BaseQuery,
                        }
                    };
                }
            }
        }

        if ( $Param{AppendIntoQuery} && $Param{Query} ) {
            if ( scalar @FulltextQuery ) {
                push @{ $Param{Query}->{Body}->{query}->{bool}->{must} }, {
                    bool => {
                        should => \@FulltextQuery,
                    }
                };
                if (@HighlightQueryFields) {
                    $Param{Query}->{Body}->{highlight}->{fields} = \@HighlightQueryFields;
                }
                return { Success => 1 };
            }
            return { Success => 2 };
        }

        $Query = {
            Fulltext             => \@FulltextQuery,
            HighlightQueryFields => \@HighlightQueryFields,
        };
    }

    my $Success = 1;
    if ( $Param{AppendIntoQuery} ) {
        $Success = 2;    # this success code mean that query wasn't changed at all
    }
    return {
        Query   => $Query,
        Success => $Success,
    };
}

1;
