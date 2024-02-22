# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Engine::ES::TicketHistory;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use parent qw( Kernel::System::Search::Object::Default::TicketHistory );

our @ObjectDependencies = (
    'Kernel::System::Main',
    'Kernel::System::Search',
);

=head1 NAME

Kernel::System::Search::Object::Engine::ES::TicketHistory - common base backend functions for specified object

=head1 DESCRIPTION

This module defines schema and rules for specified object to be used
for fallback or separate engine.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $SearchTicketHistoryESObject = $Kernel::OM->Get('Kernel::System::Search::Object::Engine::ES::TicketHistory');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    $Self->{Module} = 'Kernel::System::Search::Object::Engine::ES::TicketHistory';

    # specify base config for index
    $Self->{Config} = {
        IndexRealName        => 'ticket_history',     # index name on the engine/sql side
        IndexName            => 'TicketHistory',      # index name on the api side
        Identifier           => 'TicketHistoryID',    # column name that represents object id in the field mapping
        ChangeTimeColumnName => 'Changed',            # column representing time of updated data entry
    };

    # load settings for index
    $Self->{Config}->{Settings} = $Self->LoadSettings(
        IndexName => $Self->{Config}->{IndexName},
    );

    # define schema for data
    my $FieldMapping = {
        TicketHistoryID => {
            ColumnName => 'id',
            Type       => 'Integer'
        },
        Name => {
            ColumnName => 'name',
            Type       => 'String'
        },
        HistoryTypeID => {
            ColumnName => 'history_type_id',
            Type       => 'Integer'
        },
        TicketID => {
            ColumnName => 'ticket_id',
            Type       => 'Integer'
        },
        ArticleID => {
            ColumnName => 'article_id',
            Type       => 'Integer'
        },
        TypeID => {
            ColumnName => 'type_id',
            Type       => 'Integer'
        },
        QueueID => {
            ColumnName => 'queue_id',
            Type       => 'Integer'
        },
        OwnerID => {
            ColumnName => 'owner_id',
            Type       => 'Integer'
        },
        PriorityID => {
            ColumnName => 'priority_id',
            Type       => 'Integer'
        },
        StateID => {
            ColumnName => 'state_id',
            Type       => 'Integer'
        },
        Created => {
            ColumnName => 'create_time',
            Type       => 'Date'
        },
        CreateBy => {
            ColumnName => 'create_by',
            Type       => 'Integer'
        },
        Changed => {
            ColumnName => 'change_time',
            Type       => 'Date'
        },
        ChangeBy => {
            ColumnName => 'change_by',
            Type       => 'Integer'
        },
    };

    # get default config
    $Self->DefaultConfigGet();

    # load fields with custom field mapping
    $Self->_Load(
        Fields => $FieldMapping,
        Config => $Self->{Config},
    );

    return $Self;
}

sub Search {
    my ( $Self, %Param ) = @_;

    my $Data = $Self->PreSearch(%Param);
    return $Self->SearchEmptyResponse(%Param) if !IsHashRefWithData($Data);
    return $Self->ExecuteSearch( %{$Data} );
}

=head2 ExecuteSearch()

perform actual search

    my $Result = $SearchTicketHistoryESObject->ExecuteSearch(
        %Param,
        Limit          => $Limit,
        Fields         => $Fields,
        QueryParams    => $Param{QueryParams},
        SortBy         => $SortBy,
        OrderBy        => $OrderBy,
        RealIndexName  => $Self->{Config}->{IndexRealName},
        ResultType     => $ValidResultType,
    );

=cut

sub ExecuteSearch {
    my ( $Self, %Param ) = @_;

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');
    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');

    if ( $Param{UseSQLSearch} || $SearchObject->{Fallback} ) {
        return $Self->FallbackExecuteSearch(%Param);
    }

    my $IndexName = $Self->{Config}->{IndexName};

    my $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::$IndexName");
    my $QueryParams      = $Param{QueryParams};
    my $Fulltext         = delete $QueryParams->{Fulltext};

    # filter & prepare correct parameters
    my $SearchParams = $IndexQueryObject->_QueryParamsPrepare(
        QueryParams   => $QueryParams,
        NoPermissions => $Param{NoPermissions},
        QueryFor      => 'Engine',
        Strict        => 1,
    );

    return $Self->SearchEmptyResponse(%Param)
        if ref $SearchParams eq 'HASH' && $SearchParams->{Error};

    my $Fields = $Param{Fields} || {};

    # build standard ticket history query
    my $Query = $Param{MappingObject}->Search(
        %Param,
        Fields      => $Fields,
        QueryParams => $SearchParams,
        Object      => $Self->{Config}->{IndexName},
        _Source     => 1,
    );

    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');

    if ( defined $Fulltext ) {
        my $FulltextValue;
        my $FulltextQueryOperator = 'AND';
        my $StatementOperator     = 'OR';
        if ( ref $Fulltext eq 'HASH' && $Fulltext->{Text} ) {
            $FulltextValue         = $Fulltext->{Text};
            $FulltextQueryOperator = $Fulltext->{QueryOperator}
                if $Fulltext->{QueryOperator};
            $StatementOperator = $Fulltext->{StatementOperator}
                if $Fulltext->{StatementOperator};
        }
        else {
            $FulltextValue = $Fulltext;
        }
        if ( IsArrayRefWithData($FulltextValue) ) {
            $FulltextValue = join " $StatementOperator ", @{$FulltextValue};
        }
        if ( defined $FulltextValue && $Fulltext->{Fields} )
        {
            my @FulltextQuery;

            my $FulltextHighlight = $Fulltext->{Highlight};
            my @FulltextHighlightFieldsValid;

            # check validity of highlight fields
            if ( IsArrayRefWithData($FulltextHighlight) ) {
                for my $Property ( @{$FulltextHighlight} ) {
                    my %Field = $SearchChildObject->ValidFieldsPrepare(
                        Fields => [$Property],
                        Object => $IndexName,
                    );

                    FIELD:
                    for my $Entity ( sort keys %Field ) {
                        next FIELD if !IsHashRefWithData( $Field{$Entity} );
                        push @FulltextHighlightFieldsValid, $Property;
                        last FIELD;
                    }
                }
            }

            # get fields to search
            my $FulltextSearchFields = $Fulltext->{Fields};
            my @FulltextFields;
            my %FulltextFieldsValid;

            if ( IsArrayRefWithData( $FulltextSearchFields->{$IndexName} ) ) {
                for my $Property ( @{ $FulltextSearchFields->{$IndexName} } ) {
                    my $FulltextField = $Param{MappingObject}->FulltextSearchableFieldBuild(
                        Index  => $IndexName,
                        Entity => $IndexName,
                        Field  => $Property,
                        Simple => 1,
                    );

                    if ($FulltextField) {
                        my $Field = $FulltextField;
                        push @FulltextFields, $Field;
                        $FulltextFieldsValid{"${IndexName}_${Property}"} = $Field;
                    }
                }
            }

            # build highlight query
            my @HighlightQueryFields;
            HIGHLIGHT:
            for my $HighlightField (@FulltextHighlightFieldsValid) {
                next HIGHLIGHT if !( $FulltextFieldsValid{$HighlightField} );
                push @HighlightQueryFields, {
                    $FulltextFieldsValid{$HighlightField} => {},
                };
            }

            # clean special characters
            $FulltextValue = $Param{EngineObject}->QueryStringReservedCharactersClean(
                String => $FulltextValue,
            );

            if ( scalar @FulltextFields ) {
                push @FulltextQuery, {
                    query_string => {
                        fields           => \@FulltextFields,
                        query            => "*$FulltextValue*",
                        default_operator => $FulltextQueryOperator,
                    },
                };
            }

            if ( scalar @FulltextQuery ) {
                push @{ $Query->{Body}->{query}->{bool}->{must} }, {
                    bool => {
                        should => \@FulltextQuery,
                    }
                };
                if (@HighlightQueryFields) {
                    $Query->{Body}->{highlight}->{fields} = \@HighlightQueryFields;
                }
            }
        }
    }

    my $RetrieveHighlightData = IsHashRefWithData( $Query->{Body}->{highlight} )
        && IsArrayRefWithData( $Query->{Body}->{highlight}->{fields} );

    # execute query
    my $Response = $Param{EngineObject}->QueryExecute(
        Query         => $Query,
        Operation     => 'Search',
        ConnectObject => $Param{ConnectObject},
        Config        => $Param{GlobalConfig},
        Silent        => $Param{Silent},
    );

    # format query
    my $FormattedResult = $SearchObject->SearchFormat(
        %Param,
        Fields     => $Fields,
        Result     => $Response,
        IndexName  => $IndexName,
        ResultType => $Param{ResultType} || 'ARRAY',
        QueryData  => {
            Query                 => $Query,
            RetrieveHighlightData => $RetrieveHighlightData,
        },
    );

    return $FormattedResult;

}

=head2 FallbackExecuteSearch()

execute fallback

notice: fall-back does not support searching by fulltext

    my $FunctionResult = $SearchTicketHistoryESObject->FallbackExecuteSearch(
        %Params,
    );

=cut

sub FallbackExecuteSearch {
    my ( $Self, %Param ) = @_;

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');
    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');

    if ( $Param{QueryParams}->{Fulltext} && !$Param{Force} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Fulltext parameter is not supported for SQL search!"
        );
        return $Self->SearchEmptyResponse(%Param);
    }

    my $IndexName = $Self->{Config}->{IndexName};

    my $Result = {
        $IndexName => $Self->Fallback(%Param) // []
    };

    # format reponse per index
    my $FormattedResult = $SearchObject->SearchFormat(
        Result     => $Result,
        Config     => $Param{GlobalConfig},
        IndexName  => $IndexName,
        ResultType => $Param{ResultType} || 'ARRAY',
        Fallback   => 1,
        Silent     => $Param{Silent},
        Fields     => $Param{Fields},
    );

    return $FormattedResult || { $IndexName => [] };
}

1;
