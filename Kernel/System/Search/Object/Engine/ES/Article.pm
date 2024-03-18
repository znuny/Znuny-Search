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

use parent qw( Kernel::System::Search::Object::Default::Article Kernel::System::Search::Object::Engine::ES );
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Search::Object::Default::Ticket',
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
        IndexRealName        => 'article',       # index name on the engine/sql side
        IndexName            => 'Article',       # index name on the api side
        Identifier           => 'ArticleID',     # column name that represents object id in the field mapping
        ChangeTimeColumnName => 'ChangeTime',    # column representing time of updated data entry
    };

    # load settings for index
    $Self->{Config}->{Settings} = $Self->LoadSettings(
        IndexName => $Self->{Config}->{IndexName},
    );

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

    $Self->{AdditionalFields} = {
        GroupID => {
            ColumnName => 'group_id',
            Type       => 'Integer',
            Alias      => 0,
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

    # load fields
    $Self->_Load(
        Fields                   => $FieldMapping,
        CustomConfigNotSupported => 1,
    );

    return $Self;
}

=head2 Search()

Prepare data and parameters for engine or fallback search,
then execute search.

    my $Result = $SearchArticleESObject->Search(
        Objects       => ['Article'],
        Counter       => $Counter,
        MappingObject => $MappingObject},
        EngineObject  => $EngineObject},
        ConnectObject => $ConnectObject},
        GlobalConfig  => $Config},
    );

On executing article search by Kernel::System::Search:
    my $Result = $Kernel::OM->Get('Kernel::System::Search')->Search(
        Objects => ["Article"],
        QueryParams => {
            # standard article fields
            ArticleID              => 'value',
            TicketID               => 'value',
            SenderTypeID           => 'value',
            CommunicationChannelID => 'value',
            IsVisibleForCustomer   => '1' # or '0',
            CreateTime             => 'value',
            CreateBy               => 'value',
            ChangeTime             => 'value',
            ChangeBy               => 'value',

            # additional article fields (denormalized)
            From                   => 'value',
            ReplyTo                => 'value',
            To                     => 'value',
            Cc                     => 'value',
            Bcc                    => 'value'
            Subject                => 'value',
            MessageID              => 'value',
            InReplyTo              => 'value',
            References             => 'value',
            ContentType            => 'value',
            Body                   => 'value',
            IncomingTime           => 'value',

            # permission parameters
            # required either group id or UserID
            GroupID => [1,2,3],
            # when combined witch UserID, there is used "OR" match
            # meaning groups for specified user including groups from
            # "GroupID" will match articles
            UserID => 1, # no operators support
            Permissions => 'ro' # no operators support, by default "ro" value will be used
                                # permissions for user, therefore should be combined with UserID param

            # fulltext parameter can be used to search by properties specified
            # in sysconfig "SearchEngine::ES::ArticleSearchFields###Fulltext"
            Fulltext      => 'elasticsearch',
            #    OR
            Fulltext      => ['elasticsearch', 'kibana'],
            #    OR
            Fulltext      => {
                Highlight => ['Article_Subject', 'Article_Body'], # support ResultType: "HASH","ARRAY"
                Fields => {
                    Article => [ 'Body', 'Subject' ],
                }, # optional
                Text => ['elasticsearch', 'kibana'],
                QueryOperator => 'AND', # determine if all words from specified
                                        # value needs to match
                                        # optional, default: "AND"
                                        # possible: "OR" - only single word needs to match
                                        #           "AND" - all words needs to match
                                        # example: 'elasticsearch is super fast'
                                        # each of those are separate words, decide here if
                                        # all of them needs to be matched or only one
                StatementOperator => 'OR', # determine if all values from specified ones
                                           # in an array needs to match
                                           # optional, default: "OR"
                                           # possible: "OR" - single value from an array needs to match
                                           #           "AND" - all values from an array needs to match
                                           # use only when specifying multiple values to search by
                                           # example: ['elasticsearch is super fast', 'sql search is slower for fulltext search']
                                           # decide here if both of these values needs to matched or only one
            }
        },
        Fields => [['Article_ArticleID', 'Article_Subject']] # specify field from field mapping
            # to get:
            # - article fields (all): [['Article_*']]
            # - article field (specified): [['Article_Body']]
    );

=cut

sub Search {
    my ( $Self, %Param ) = @_;

    my $Data = $Self->PreSearch(%Param);
    return $Self->SearchEmptyResponse(%Param) if !IsHashRefWithData($Data);
    return $Self->ExecuteSearch( %{$Data} );
}

=head2 ExecuteSearch()

perform actual search

    my $Result = $SearchArticleESObject->ExecuteSearch(
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

    # build standard article query
    my $Query = $Param{MappingObject}->Search(
        %Param,
        Fields      => $Fields,
        QueryParams => $SearchParams,
        Object      => $Self->{Config}->{IndexName},
        _Source     => 1,
    );

    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');

    my $FulltextQuery = $Self->DefaultFulltextQueryBuild(
        Query               => $Query,
        AppendIntoQuery     => 1,
        EngineObject        => $Param{EngineObject},
        MappingObject       => $Param{MappingObject},
        Fulltext            => $Fulltext,
        EntitiesPathMapping => {
            Article => {
                Path             => '',
                FieldBuildPrefix => '',
                Nested           => 0,
            },
        },
        DefaultFields => {},
        Simple        => 1,
    );

    return $Self->SearchEmptyResponse(%Param) if !$FulltextQuery->{Success};

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

    my $FunctionResult = $SearchArticleESObject->FallbackExecuteSearch(
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

sub ObjectIndexAdd() {
    my ( $Self, %Param ) = @_;

    return $Self->ObjectIndexGeneric(
        %Param,
        Function => $Param{Function} || '_ObjectIndexAddAction',
    );
}

sub ObjectIndexSet() {
    my ( $Self, %Param ) = @_;

    return $Self->ObjectIndexGeneric(
        %Param,
        Function => '_ObjectIndexSetAction',
    );
}

sub ObjectIndexUpdate() {
    my ( $Self, %Param ) = @_;

    return $Self->ObjectIndexGeneric(
        %Param,
        Function => '_ObjectIndexUpdateAction',
    );
}

sub ObjectIndexUpdateTicketArticles() {
    my ( $Self, %Param ) = @_;

    return $Self->ObjectIndexGeneric(
        %Param,
        Function => '_ObjectIndexUpdateTicketArticlesAction',
    );
}

=head2 ObjectIndexGeneric()

search for articles with restrictions, then perform specified operation

    my $Success = $SearchArticleObject->ObjectIndexGeneric(
        Index    => 'Article',
        Refresh  => 1, # optional, define if indexed data needs
                       # to be refreshed for search call
                       # not refreshed data could not be found right after
                       # indexing (for example in elastic search engine)

        ObjectID => 1, # possible:
                       # - for single object indexing: 1
                       # - for multiple object indexing: [1,2,3]
        # or
        QueryParams => {
            ArticleID => [1,2,3],
            TicketID => [1 .. 500],
        },

        Function => 'FunctionName' # function callback name
                                   # to which the object data
                                   # will be sent
        # article data can be indexed into ticket or article index
        IndexInto => 'Ticket', # possible: 'Ticket', 'Article'
    );

=cut

sub ObjectIndexGeneric {
    my ( $Self, %Param ) = @_;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $IndexInto    = $Param{IndexInto} || 'Article';
    my $Function     = $Param{Function};

    return if !$Function;
    return if !$Self->_BaseCheckIndexOperation(
        %Param,
    ) && $IndexInto eq 'Article';

    my $Identifier = $Self->{Config}->{Identifier};

    my $QueryParams = $Param{QueryParams} ? $Param{QueryParams} : {
        $Identifier => $Param{ObjectID},
    };

    my $DataCount;
    my $SQLDataIDs;

    # object id limit to process at once
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
            Limit       => $IDLimit,
            Offset      => $ArticleOffset,
            SortBy      => $Identifier,
            OrderBy     => 'Down',
        );

        $DataCount = scalar @{$SQLDataIDs};
        if ($DataCount) {

            # no need to object count restrictions
            if ( $DataCount <= $ReindexationStep ) {
                my $SQLSearchResult = $Self->SQLObjectSearch(
                    %Param,
                    QueryParams => {
                        $Identifier => $SQLDataIDs,
                    },
                    SortBy     => $Identifier,
                    OrderBy    => 'Down',
                    ResultType => $Param{SQLSearchResultType} || 'ARRAY',
                    IndexInto  => $IndexInto,
                );

                my $SuccessLocal = $Self->$Function(
                    %Param,
                    DataToIndex => $SQLSearchResult,
                    IndexInto   => $IndexInto,
                );

                $Success = $SuccessLocal if $Success && !$SuccessLocal;
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
                        SortBy     => $Identifier,
                        OrderBy    => 'Down',
                        ResultType => $Param{SQLSearchResultType} || 'ARRAY',
                        Offset     => $Offset,
                        Limit      => $ReindexationStep,
                        IndexInto  => $IndexInto,
                    );

                    my $PartSuccess = $Self->$Function(
                        %Param,
                        DataToIndex => $SQLSearchResult,
                        IndexInto   => $IndexInto,
                    );

                    $Success = $PartSuccess if $Success && !$PartSuccess;
                }
            }
        }

        # index all data in parts until no more will be found
    } while ( $DataCount == $IDLimit );

    return $Success;
}

=head2 SQLObjectSearch()

Search for article data.

    my $FunctionResult = $SearchArticleObject->SQLObjectSearch(
        QueryParams => {
            TicketID => 1,
            ArticleID => 1,
        }
    );

=cut

sub SQLObjectSearch {
    my ( $Self, %Param ) = @_;

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my $ExternalFields;
    my $Join = {
        Type  => 'INNER JOIN',
        Table => 'article_data_mime',
        On    => 'article.id = article_data_mime.article_id',
    };

    my $Fields = $Param{Fields};

    # treat external fields (fields from table article_data_mime) as searchable fields
    # as there will be inner join performed
    my %CustomIndexFields = ( %{ $Self->{Fields} }, %{ $Self->{ExternalFields} } );

    if ( IsArrayRefWithData( $Param{Fields} ) ) {
        my @ExternalArticleFields = grep { $Self->{ExternalFields}->{$_} } @{ $Param{Fields} };

        # no article_data_mime fields to retrieve found,
        # meaning join on sql is not needed
        if ( !scalar @ExternalArticleFields ) {
            undef $Join;
        }
    }
    elsif ( IsHashRefWithData( $Param{Fields} ) ) {
        my @ExternalArticleFields = grep { $Self->{ExternalFields}->{$_} } keys %{ $Param{Fields} };

        # no article_data_mime fields to retrieve found,
        # meaning join on sql is not needed
        if ( !scalar @ExternalArticleFields ) {
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
        NoPermissions     => 1,
    );

    if ( $Param{IndexInto} && $Param{IndexInto} eq 'Article' ) {
        my $GroupField = $Self->{AdditionalFields}->{GroupID};

        if ( IsArrayRefWithData( $ArticleData->{Data} ) ) {
            for my $Article ( @{ $ArticleData->{Data} } ) {
                my $TicketID = $Article->{TicketID};

                my %Ticket = $TicketObject->TicketGet(
                    TicketID      => $TicketID,
                    DynamicFields => 0,
                    UserID        => 1,
                );

                $Article->{GroupID} = $Ticket{GroupID};
            }
        }
    }

    return $ArticleData;
}

=head2 ValidFieldsPrepare()

validates fields for object and return only valid ones

    my %Fields = $SearchArticleObject->ValidFieldsPrepare(
        Fields => $Fields,     # optional
        Object => $ObjectName,
    );

=cut

sub ValidFieldsPrepare {
    my ( $Self, %Param ) = @_;

    my $Fields;
    my $ArticleBasicFields      = $Self->{Fields};
    my $ArticleExternalFields   = $Self->{ExternalFields};
    my $ArticleAdditionalFields = $Self->{AdditionalFields};

    my %InternalExternalArticleFields = ( %{$ArticleBasicFields}, %{$ArticleExternalFields} );
    my %AllArticleFields              = ( %InternalExternalArticleFields, %{$ArticleAdditionalFields} );

    if ( !IsArrayRefWithData( $Param{Fields} ) ) {
        $Fields = \%InternalExternalArticleFields;
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

    my %Fields = $SearchArticleObject->_PostValidFieldsPrepare(
        ValidFields => $ValidFields,
    );

=cut

sub _PostValidFieldsPrepare {
    my ( $Self, %Param ) = @_;

    return () if !IsHashRefWithData( $Param{Fields} );

    my %ValidFields = %{ $Param{Fields} };

    FIELD:
    for my $Field ( sort keys %ValidFields ) {
        $ValidFields{$Field}
            = $Self->{Fields}->{$Field} || $Self->{ExternalFields}->{$Field} || $Self->{AdditionalFields}->{$Field};
        $ValidFields{$Field}->{ReturnType} = 'SCALAR' if !$ValidFields{$Field}->{ReturnType};
    }

    return %ValidFields;
}

sub _ObjectIndexAddAction {
    my ( $Self, %Param ) = @_;

    # index article into Article index
    return $Self->SUPER::_ObjectIndexAction(
        %Param,
        Function => 'ObjectIndexAdd',
    ) if $Param{IndexInto} eq 'Article';

    # index article into Ticket index
    my $SearchTicketObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::Ticket');
    return $SearchTicketObject->ObjectIndexArticle(
        ArticleData   => $Param{DataToIndex},
        EngineObject  => $Param{EngineObject},
        ConnectObject => $Param{ConnectObject},
        MappingObject => $Param{MappingObject},
        Action        => 'AddArticle',
    );
}

sub _ObjectIndexSetAction {
    my ( $Self, %Param ) = @_;

    # index article into Article index
    return $Self->SUPER::_ObjectIndexAction(
        %Param,
        Function => 'ObjectIndexSet',
    ) if $Param{IndexInto} eq 'Article';

    # index article into Ticket index
    my $SearchTicketObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::Ticket');
    return $SearchTicketObject->ObjectIndexArticle(
        ArticleData   => $Param{DataToIndex},
        EngineObject  => $Param{EngineObject},
        ConnectObject => $Param{ConnectObject},
        MappingObject => $Param{MappingObject},
        Action        => 'AddArticle',
    );
}

sub _ObjectIndexUpdateAction {
    my ( $Self, %Param ) = @_;

    # index article into Article index
    return $Self->SUPER::_ObjectIndexAction(
        %Param,
        Function => 'ObjectIndexUpdate',
    ) if $Param{IndexInto} eq 'Article';

    # index article into Ticket index
    my $SearchTicketObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::Ticket');
    return $SearchTicketObject->ObjectIndexArticle(
        %Param,
        ArticleData => $Param{DataToIndex},
    );
}

sub _ObjectIndexUpdateTicketArticlesAction {
    my ( $Self, %Param ) = @_;

    # update/add article on Ticket index
    my $SearchTicketObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::Ticket');
    return $SearchTicketObject->ObjectIndexArticle(
        %Param,
        ArticleData => $Param{DataToIndex},
    );
}

1;
