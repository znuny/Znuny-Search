# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Engine::ES::Article;

use strict;
use warnings;
use POSIX qw/ceil/;

use parent qw( Kernel::System::Search::Object::Default::Article );
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Main',
    'Kernel::System::Search',
);

=head1 NAME

Kernel::System::Search::Object::Engine::ES::Article - common base backend functions for specified object

=head1 DESCRIPTION

This module defines schema and rules for specified object to be used
for fallback or separate engine.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $SearchArticleObject = $Kernel::OM->Get('Kernel::System::Search::Object::Engine::ES::Article');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    $Self->{Module} = "Kernel::System::Search::Object::Engine::ES::Article";

    # specify base config for index
    $Self->{Config} = {
        IndexRealName => 'article',      # index name on the engine/sql side
        IndexName     => 'Article',      # index name on the api side
        Identifier    => 'ArticleID',    # column name that represents object id in the field mapping
    };

    # define schema for data
    my $FieldMapping = {
        ArticleID => {
            ColumnName => 'id',
            Type       => 'Integer',
        },
        TicketID => {
            ColumnName => 'ticket_id',
            Type       => 'Integer',
        },
        SenderTypeID => {
            ColumnName => 'article_sender_type_id',
            Type       => 'Integer'
        },
        CommunicationChannelID => {
            ColumnName => 'communication_channel_id',
            Type       => 'Integer'
        },
        IsVisibleForCustomer => {
            ColumnName => 'is_visible_for_customer',
            Type       => 'Integer'
        },
        CreateTime => {
            ColumnName => 'create_time',
            Type       => 'Date'
        },
        CreateBy => {
            ColumnName => 'create_by',
            Type       => 'Integer'
        },
        ChangeTime => {
            ColumnName => 'change_time',
            Type       => 'Date'
        },
        ChangeBy => {
            ColumnName => 'change_by',
            Type       => 'Integer'
        },
    };

    $Self->{ExternalFields} = {
        From => {
            ColumnName => 'a_from',
            Type       => 'String'
        },
        ReplyTo => {
            ColumnName => 'a_reply_to',
            Type       => 'String'
        },
        To => {
            ColumnName => 'a_to',
            Type       => 'String'
        },
        Cc => {
            ColumnName => 'a_cc',
            Type       => 'String'
        },
        Bcc => {
            ColumnName => 'a_bcc',
            Type       => 'String'
        },
        Subject => {
            ColumnName => 'a_subject',
            Type       => 'String'
        },
        MessageID => {
            ColumnName => 'a_message_id',
            Type       => 'String'
        },
        InReplyTo => {
            ColumnName => 'a_in_reply_to',
            Type       => 'String'
        },
        References => {
            ColumnName => 'a_references',
            Type       => 'String'
        },
        ContentType => {
            ColumnName => 'a_content_type',
            Type       => 'String'
        },
        Body => {
            ColumnName => 'a_body',
            Type       => 'Textarea'
        },
        IncomingTime => {
            ColumnName => 'incoming_time',
            Type       => 'Long'
        },
    };

    # define searchable fields
    # that can be used as query parameters
    # for either indexing or searching
    $Self->{SearchableFields} = {
        SQL    => '*',
        Engine => '*',
    };

    # get default config
    $Self->DefaultConfigGet();

    # restrict usage of other operators than default one
    # for SQL search
    $Self->{SupportedOperators}->{SimplifiedMode} = {
        SQL => 1,
    };

    # load fields
    $Self->_Load(
        Fields                   => $FieldMapping,
        CustomConfigNotSupported => 1,
    );

    return $Self;
}

sub ObjectIndexAdd {
    my ( $Self, %Param ) = @_;

    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
    my $LogObject          = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchTicketObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::Ticket');

    return if !$Self->_BaseCheckIndexOperation(%Param);

    my $Identifier = $Self->{Config}->{Identifier};

    my $QueryParams = $Param{QueryParams} ? $Param{QueryParams} : {
        $Identifier => $Param{ObjectID},
    };

    my $DataCount;
    my $SQLDataIDs;

    # article id limit to process at once
    my $IDLimit = 100_000;

    # additional limit for single request
    my $ReindexationSettings = $ConfigObject->Get('SearchEngine::Reindexation')->{Settings};
    my $ReindexationStep     = $ReindexationSettings->{ReindexationStep} // 10;

    # success is hard to identify for that many objects
    # simply return 1 when 100% of data will execute queries
    # correctly, otherwise return 0
    my $Success                 = 1;
    my $ArticleOffsetMultiplier = 0;

    do {
        my $ArticleOffset = $ArticleOffsetMultiplier++ * $IDLimit;

        $SQLDataIDs = $Self->ObjectListIDs(
            QueryParams => $QueryParams,
            Fields      => [$Identifier],
            ResultType  => 'ARRAY',
            Limit       => $IDLimit,
            Offset      => $ArticleOffset,
        );

        $DataCount = scalar @{$SQLDataIDs};

        # indexation of ticket base values with it's dynamic fields
        # index object without any restrictions on first level
        # ignore restrictions on single object id and reindexation as it does have it's
        # own mechanism to restrict data size
        if ( $Param{Reindex} || ( $Param{ObjectID} && IsNumber( $Param{ObjectID} ) ) ) {
            my $SQLSearchResult = $Self->SUPER::SQLObjectSearch(
                %Param,
                QueryParams => {
                    $Identifier => $SQLDataIDs,
                },
                ResultType    => $Param{SQLSearchResultType} || 'ARRAY',
                NoPermissions => 1,
            );

            $Success = $Self->_ObjectIndexAddAction(
                %Param,
                DataToIndex => $SQLSearchResult,
            ) if $Success;

            # do not count failures of indexing articles on ticket index
            $SearchTicketObject->ObjectIndexAddArticle(
                ArticleData   => $SQLSearchResult,
                EngineObject  => $Param{EngineObject},
                ConnectObject => $Param{ConnectObject},
            );
        }
        else {
            # no need to object count restrictions
            if ( $DataCount <= $ReindexationStep ) {
                my $SQLSearchResult = $Self->SQLObjectSearch(
                    %Param,
                    QueryParams => {
                        $Identifier => $SQLDataIDs,
                    },
                    ResultType    => $Param{SQLSearchResultType} || 'ARRAY',
                    NoPermissions => 1,
                );

                $Success = $Self->_ObjectIndexAddAction(
                    %Param,
                    DataToIndex => $SQLSearchResult,
                ) if $Success;

                # do not count failures of indexing articles on ticket index
                $SearchTicketObject->ObjectIndexAddArticle(
                    ArticleData   => $SQLSearchResult,
                    EngineObject  => $Param{EngineObject},
                    ConnectObject => $Param{ConnectObject},
                );
            }
            else {
                # restrict data size
                my $IterationCount = ceil( $DataCount / $ReindexationStep );

                # index data in parts
                for my $OffsetMultiplier ( 0 .. $IterationCount - 1 ) {
                    my $Offset = $OffsetMultiplier * $ReindexationStep;

                    my $SQLSearchResult = $Self->SQLObjectSearch(
                        %Param,
                        QueryParams => {
                            $Identifier => $SQLDataIDs,
                        },
                        ResultType    => $Param{SQLSearchResultType} || 'ARRAY',
                        Offset        => $Offset,
                        Limit         => $ReindexationStep,
                        NoPermissions => 1,
                    );

                    my $PartSuccess = $Self->_ObjectIndexAddAction(
                        %Param,
                        DataToIndex => $SQLSearchResult,
                    );

                    $Success = $PartSuccess if $Success && !$PartSuccess;

                    # do not count failures of indexing articles on ticket index
                    $SearchTicketObject->ObjectIndexAddArticle(
                        ArticleData   => $SQLSearchResult,
                        EngineObject  => $Param{EngineObject},
                        ConnectObject => $Param{ConnectObject},
                    );
                }
            }
        }

        # index all data in parts until no more will be found
    } while ( $DataCount == $IDLimit );

    return $Success;
}

=head2 SQLObjectSearch()

Search for article data. Do not pass operators for ticket/article id.

    my $FunctionResult = $Object->SQLObjectSearch(
        QueryParams => {
            TicketID => 1, # required, possible: 1, [1,2,3]
            # OR
            ArticleID => 1, # required, possible: 1, [1,2,3]
        }
    );

=cut

sub SQLObjectSearch {
    my ( $Self, %Param ) = @_;

    my $ExternalFields;
    my $Join = {
        Type  => 'INNER JOIN',
        Table => 'article_data_mime',
        On    => 'article.id = article_data_mime.article_id',
    };

    my $Fields            = $Param{Fields};
    my %CustomIndexFields = ( %{ $Self->{Fields} }, %{ $Self->{ExternalFields} } );

    if ( IsArrayRefWithData( $Param{Fields} ) ) {
        my @ExternalArticleFields = grep { $Self->{ExternalFields}->{$_} } @{ $Param{Fields} };
        if ( scalar @ExternalArticleFields ) {
            $ExternalFields = \@ExternalArticleFields;
        }
        else {
            undef $Join;
        }
    }
    else {
        $Fields = \%CustomIndexFields;
    }

    my $ArticleData = $Self->SUPER::SQLObjectSearch(
        %Param,
        Join              => $Join,
        Fields            => $Fields,
        CustomIndexFields => \%CustomIndexFields,
    );

    return $ArticleData;
}

=head2 ValidFieldsPrepare()

validates fields for object and return only valid ones

    my %Fields = $SearchChildObject->ValidFieldsPrepare(
        Fields => $Fields,     # optional
        Object => $ObjectName,
    );

=cut

sub ValidFieldsPrepare {
    my ( $Self, %Param ) = @_;

    my $Fields;
    my $ArticleBasicFields    = $Self->{Fields};
    my $ArticleExternalFields = $Self->{ExternalFields};

    my %AllArticleFields = ( %{$ArticleBasicFields}, %{$ArticleExternalFields} );

    if ( !IsArrayRefWithData( $Param{Fields} ) || $Param{Param}->{UseSQLSearch} ) {
        $Fields = \%AllArticleFields;
    }
    else {
        for my $ParamField ( @{ $Param{Fields} } ) {
            if ( $ParamField =~ m{^Article_(.+)} ) {
                my $ArticleField = $1;
                if ( $ArticleField && $ArticleField eq '*' ) {
                    for my $ArticleFieldName ( sort keys %AllArticleFields ) {
                        $Fields->{$ArticleFieldName} = $AllArticleFields{$ArticleFieldName};
                    }
                }
                else {
                    $Fields->{$ArticleField} = $AllArticleFields{$ArticleField}
                        if $AllArticleFields{$ArticleField};
                }
            }
        }
    }

    return $Self->_PostValidFieldsPrepare(
        Fields => $Fields,
    );
}

=head2 _PostValidFieldsPrepare()

set fields return type if not specified

    my %Fields = $SearchTicketESObject->_PostValidFieldsPrepare(
        ValidFields => $ValidFields,
    );

=cut

sub _PostValidFieldsPrepare {
    my ( $Self, %Param ) = @_;

    return () if !IsHashRefWithData( $Param{Fields} );

    my %ValidFields = %{ $Param{Fields} };

    FIELD:
    for my $Field ( sort keys %ValidFields ) {
        $ValidFields{$Field} = $Self->{Fields}->{$Field};
        $ValidFields{$Field}->{ReturnType} = 'SCALAR' if !$ValidFields{$Field}->{ReturnType};
    }

    return %ValidFields;
}

1;
