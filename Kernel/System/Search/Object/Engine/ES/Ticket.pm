# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Engine::ES::Ticket;

use strict;
use warnings;

use parent qw( Kernel::System::Search::Object::Default::Ticket );
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Search::Object',
    'Kernel::System::Log',
    'Kernel::System::Search',
    'Kernel::System::DB',
    'Kernel::System::Ticket::Article',
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicField::Backend',
);

=head1 NAME

Kernel::System::Search::Object::Engine::ES::Ticket - common base backend functions for specified object

=head1 DESCRIPTION

This module defines schema and rules for specified object to be used
for fallback or separate engine.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $SearchTicketESObject = $Kernel::OM->Get('Kernel::System::Search::Object::Engine::ES::Ticket');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    $Self->{Module} = 'Kernel::System::Search::Object::Engine::ES::Ticket';

    # specify base config for index
    $Self->{Config} = {
        IndexRealName => 'ticket',      # index name on the engine/sql side
        IndexName     => 'Ticket',      # index name on the api side
        Identifier    => 'TicketID',    # column name that represents object id in the field mapping
    };

    # define schema for data
    my $FieldMapping = {
        TicketID => {
            ColumnName => 'id',
            Type       => 'Integer'
        },
        TicketNumber => {
            ColumnName => 'tn',
            Type       => 'Long'
        },
        Title => {
            ColumnName => 'title',
            Type       => 'String'
        },
        QueueID => {
            ColumnName => 'queue_id',
            Type       => 'Integer'
        },
        LockID => {
            ColumnName => 'ticket_lock_id',
            Type       => 'Integer'
        },
        TypeID => {
            ColumnName => 'type_id',
            Type       => 'Integer'
        },
        ServiceID => {
            ColumnName => 'service_id',
            Type       => 'Integer'
        },
        SLAID => {
            ColumnName => 'sla_id',
            Type       => 'Integer'
        },
        OwnerID => {
            ColumnName => 'user_id',
            Type       => 'Integer'
        },
        ResponsibleID => {
            ColumnName => 'responsible_user_id',
            Type       => 'Integer'
        },
        PriorityID => {
            ColumnName => 'ticket_priority_id',
            Type       => 'Integer'
        },
        StateID => {
            ColumnName => 'ticket_state_id',
            Type       => 'Integer'
        },
        CustomerID => {
            ColumnName => 'customer_id',
            Type       => 'String'
        },
        CustomerUserID => {
            ColumnName => 'customer_user_id',
            Type       => 'String'
        },
        UnlockTimeout => {
            ColumnName => 'timeout',
            Type       => 'Integer'
        },
        UntilTime => {
            ColumnName => 'until_time',
            Type       => 'Integer'
        },
        EscalationTime => {
            ColumnName => 'escalation_time',
            Type       => 'Integer'
        },
        EscalationUpdateTime => {
            ColumnName => 'escalation_update_time',
            Type       => 'Integer'
        },
        EscalationResponseTime => {
            ColumnName => 'escalation_response_time',
            Type       => 'Integer'
        },
        EscalationSolutionTime => {
            ColumnName => 'escalation_solution_time',
            Type       => 'Integer'
        },
        ArchiveFlag => {
            ColumnName => 'archive_flag',
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

=head2 Search()

Prepare data and parameters for engine or fallback search,
then execute search.

    my $Result = $SearchTicketESObject->Search(
        TicketID => $Param{TicketID},
        Objects       => ['Ticket'],
        Counter       => $Counter,
        MappingObject => $MappingObject},
        EngineObject  => $EngineObject},
        ConnectObject => $ConnectObject},
        GlobalConfig  => $Config},
    );

On executing ticket search by Kernel::System::Search:
    my $Result = $Kernel::OM->Get('Kernel::System::Search')->Search( ## nofilter(TidyAll::Plugin::Znuny4OTRS::Perl::ObjectManagerDirectCall)
        Objects => ["Ticket"],
        QueryParams => {
            TicketID => 1,
            TicketNumber => 2022101276000016,
            Title => 'some-title',
            QueueID => 1,
            LockID => 1,
            TypeID => 1,
            ServiceID => 1,
            SLAID => 1, ## nofilter(TidyAll::Plugin::OTRS::Perl::Pod::SpellCheck)
            OwnerID => 1,
            ResponsibleID => 1,
            PriorityID => 1,
            StateID => 1,
            CustomerID => '333',
            CustomerUserID => 'some-customer-user-id',
            UnlockTimeout => 0,
            UntilTime => 0,
            EscalationTime => 0,
            EscalationUpdateTime => 0,
            EscalationResponseTime => 0,
            EscalationSolutionTime => 0,
            ArchiveFlag => 1,
            Created => "2022-08-17 13:13:23",
            CreateBy => 1,
            Changed => "2022-08-17 13:13:39",
            ChangeBy => 1,
            DynamicField_Name1 => 'value',
            DynamicField_Name2 => 'value',
            Article_From => 'value',
            Article_To => 'value',
            Article_Cc => 'value',
            Article_Subject => 'value',
            Article_Body => 'value',
            Article_*OtherArticleDataMIMEValues* => 'value',
            Article_SenderTypeID => 'value',           # no operators support yet
            Article_CommunicationChannelID => 'value', # no operators support yet
            Article_IsVisibleForCustomer => 1/0        # no operators support yet
        },
        Fields => [['TicketID', 'TicketNumber']] # specify field from field mapping
            # to get all dynamic fields: [['DynamicField_*']]
            # to get specified dynamic fields: [['DynamicField_multiselect', 'DynamicField_dropdown']]
    );

    Parameter "AdvancedSearchQuery" is not supported on this Object.

=cut

sub Search {
    my ( $Self, %Param ) = @_;

    my $SearchObject      = $Kernel::OM->Get('Kernel::System::Search');
    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');
    my $LogObject         = $Kernel::OM->Get('Kernel::System::Log');

    # copy standard param to avoid overwriting on standarization
    my %Params     = %Param;
    my $IndexName  = 'Ticket';
    my $ObjectData = $Params{Objects}->{$IndexName};

    my $Loaded = $SearchChildObject->_LoadModule(
        Module => "Kernel::System::Search::Object::Query::${IndexName}",
    );

    return if !$Loaded;

    my $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::${IndexName}");

    # check/set valid result type
    my $ValidResultType = $SearchChildObject->ValidResultType(
        SupportedResultTypes => $IndexQueryObject->{IndexSupportedResultTypes},
        ResultType           => $Param{ResultType},
    );

    # do not build query for objects
    # with not valid result type
    return if !$ValidResultType;

    my $OrderBy     = $ObjectData->{OrderBy};
    my $SortByCheck = $ObjectData->{SortBy};
    my $Limit       = $ObjectData->{Limit};
    my $Fields      = $ObjectData->{Fields};
    my $SortBy;
    if ($SortByCheck)
    {
        my $Sortable = $Self->IsSortableResultType(
            ResultType => $ValidResultType,
        );

        if ( $Sortable && $Self->{Fields}->{$SortByCheck} ) {

            # change into real column name
            $SortBy = $Self->{Fields}->{$SortByCheck};
        }
        else {
            if ( !$Param{Silent} ) {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "Can't sort index: \"$Self->{Config}->{IndexName}\" with result type:" .
                        " \"$Param{ResultType}\" by field: \"$SortByCheck\".\n" .
                        "Specified result type is not sortable or field does not exists in the index!\n" .
                        "Sort operation won't be applied."
                );
            }
        }
    }

    return $Self->ExecuteSearch(
        %Param,
        Limit => $Limit
            || $IndexQueryObject->{IndexDefaultSearchLimit},    # default limit or override with limit from param
        Fields        => $Fields,
        QueryParams   => $Param{QueryParams},
        SortBy        => $SortBy,
        OrderBy       => $OrderBy,
        RealIndexName => $Self->{Config}->{IndexRealName},
        ResultType    => $ValidResultType,
    );
}

=head2 ExecuteSearch()

perform actual search

    my $Result = $SearchTicketESObject->ExecuteSearch(
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

    if ( $Param{UseSQLSearch} || $SearchObject->{Fallback} ) {
        return $Self->FallbackExecuteSearch(%Param);
    }

    my @QueryParamsKey = keys %{ $Param{QueryParams} };
    my %ArticleParam   = map { $_ => $Param{QueryParams}->{$_} } grep { $_ =~ /Article_/ } @QueryParamsKey;

    my $ObjectIDs;

    if ( keys %ArticleParam ) {
        $ObjectIDs = $Self->_SearchByArticle(
            Articles      => \%ArticleParam,
            ObjectID      => $ObjectIDs,
            ConnectObject => $Param{ConnectObject},
            EngineObject  => $Param{EngineObject},
        );

        if ( !IsArrayRefWithData($ObjectIDs) ) {

            # format query
            my $FormattedResult = $SearchObject->SearchFormat(
                IndexName  => 'Ticket',
                Operation  => 'Search',
                ResultType => $Param{ResultType} || 'ARRAY',
                Fields     => $Param{Fields},
            );

            return $FormattedResult;
        }
    }

    my $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::$Self->{Config}->{IndexName}");

    # filter & prepare correct parameters
    my $SearchParams = $IndexQueryObject->_QueryParamsPrepare(
        QueryParams => { %{ $Param{QueryParams} }, ( ObjectID => $ObjectIDs ) },
    );

    # build query
    my $Query = $Param{MappingObject}->Search(
        %Param,
        FieldsDefinition => $Self->{Fields},
        QueryParams      => $SearchParams,
        Object           => $Self->{Config}->{IndexName},
    );

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
        Result     => $Response,
        IndexName  => 'Ticket',
        Operation  => 'Search',
        ResultType => $Param{ResultType} || 'ARRAY',
        QueryData  => {
            Query => $Query
        },
    );

    return $FormattedResult;

}

=head2 FallbackExecuteSearch()

execute full fallback for searching tickets

notice: fall-back does not support searching by dynamic fields/articles yet

    my $FunctionResult = $SearchTicketESObject->FallbackExecuteSearch(
        %Params,
    );

=cut

sub FallbackExecuteSearch {
    my ( $Self, %Param ) = @_;

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');

    # prevent printing out all of tickets
    my @QueryParamsKey     = keys %{ $Param{QueryParams} };
    my %DynamicFieldsParam = map { $_ => $Param{QueryParams}->{$_} } grep { $_ =~ /DynamicField_/ } @QueryParamsKey;
    my %ArticleParam       = map { $_ => $Param{QueryParams}->{$_} } grep { $_ =~ /Article_/ } @QueryParamsKey;

    my $Result;
    if ( !%DynamicFieldsParam && !%ArticleParam ) {
        $Result = {
            Ticket => $Self->Fallback(%Param)
        };
    }

    # format reponse per index
    my $FormattedResult = $SearchObject->SearchFormat(
        Result     => $Result,
        Config     => $Param{GlobalConfig},
        IndexName  => $Self->{Config}->{IndexName},
        Operation  => "Search",
        ResultType => $Param{ResultType} || 'ARRAY',
        Fallback   => 1,
        Silent     => $Param{Silent},
        Fields     => $Param{Fields},
    );

    return $FormattedResult || { Ticket => [] };
}

=head2 ObjectIndexAdd()

add object for specified index

    my $Success = $SearchTicketESObject->ObjectIndexAdd(
        Index    => 'Ticket',
        Refresh  => 1, # optional, define if indexed data needs
                       # to be refreshed for search call
                       # not refreshed data could not be found right after
                       # indexing (for example in elastic search engine)

        ObjectID => 1, # possible:
                       # - for single object indexing: 1
                       # - for multiple object indexing: [1,2,3]
        # or
        QueryParams => {
            TicketID => [1,2,3],
            SLAID => {
                Operator => 'IS NOT EMPTY'
            },
        },
    );

=cut

sub ObjectIndexAdd {
    my ( $Self, %Param ) = @_;

    return $Self->SUPER::ObjectIndexAdd(%Param);
}

=head2 ObjectIndexSet()

set (update if exists or create if not exists) object for specified index

    my $Success = $SearchTicketESObject->ObjectIndexSet(
        Index    => "Ticket",
        Refresh  => 1, # optional, define if indexed data needs
                       # to be refreshed for search call
                       # not refreshed data could not be found right after
                       # indexing (for example in elastic search engine)

        ObjectID => 1, # possible:
                       # - for single object indexing: 1
                       # - for multiple object indexing: [1,2,3]
        # or
        QueryParams => {
            TicketID => [1,2,3],
            SLAID => {
                Operator => 'IS NOT EMPTY'
            },
        },
    );

=cut

sub ObjectIndexSet {
    my ( $Self, %Param ) = @_;

    return $Self->SUPER::ObjectIndexSet(%Param);
}

=head2 ObjectIndexUpdate()

update object for specified index

    my $Success = $SearchTicketESObject->ObjectIndexUpdate(
        Index => "Ticket",
        Refresh  => 1, # optional, define if indexed data needs
                       # to be refreshed for search call
                       # not refreshed data could not be found right after
                       # indexing (for example in elastic search engine)

        ObjectID => 1, # possible:
                       # - for single object indexing: 1
                       # - for multiple object indexing: [1,2,3]
        # or
        QueryParams => {
            TicketID => [1,2,3],
            SLAID => {
                Operator => 'IS NOT EMPTY'
            },
        },
    );

=cut

sub ObjectIndexUpdate {
    my ( $Self, %Param ) = @_;

    return $Self->SUPER::ObjectIndexUpdate(%Param);
}

=head2 SQLObjectSearch()

search in sql database for objects index related

    my $Result = $SearchTicketESObject->SQLObjectSearch(
        QueryParams => {
            TicketID => 1,
        },
        Fields      => ['TicketID', 'SLAID'] # optional, returns all
                                             # fields if not specified
        SortBy      => $IdentifierSQL,
        OrderBy     => "Down",  # possible: "Down", "Up",
        ResultType  => $ResultType,
        Limit       => 10,
    );

=cut

sub SQLObjectSearch {
    my ( $Self, %Param ) = @_;

    # perform default sql object search
    my $SQLSearchResult = $Self->SUPER::SQLObjectSearch(%Param);

    # get dynamic field objects
    my $DynamicFieldObject        = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    # get all dynamic fields for the object type Ticket
    my $DynamicFieldList = $DynamicFieldObject->DynamicFieldListGet(
        ObjectType => 'Ticket'
    );

    if ( IsArrayRefWithData($SQLSearchResult) ) {
        for my $Row ( @{$SQLSearchResult} ) {
            DYNAMICFIELD:
            for my $DynamicFieldConfig ( @{$DynamicFieldList} ) {

                # validate each dynamic field
                next DYNAMICFIELD if !$DynamicFieldConfig;
                next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);
                next DYNAMICFIELD if !$DynamicFieldConfig->{Name};

                # get the current value for each dynamic field
                my $Value = $DynamicFieldBackendObject->ValueGet(
                    DynamicFieldConfig => $DynamicFieldConfig,
                    ObjectID           => $Row->{id},
                );

                # set the dynamic field name and value into the ticket hash
                # only if value is defined
                if ( defined $Value ) {
                    $Row->{ 'DynamicField_' . $DynamicFieldConfig->{Name} } = $Value;
                }
            }
        }
    }

    return $SQLSearchResult;
}

sub _SearchByArticle {
    my ( $Self, %Param ) = @_;

    my $SearchObject  = $Kernel::OM->Get('Kernel::System::Search');
    my $ArticleObject = $Kernel::OM->Get('Kernel::System::Ticket::Article');
    my $DBObject      = $Kernel::OM->Get('Kernel::System::DB');

    # mapping for "article" to prevent overwriting params for ArticleDataMIME
    my %ArticleTableExternalColumns = (
        CommunicationChannelID => 'communication_channel_id',
        IsVisibleForCustomer   => 'is_visible_for_customer',
        SenderTypeID           => 'article_sender_type_id',
    );

    my %AdditionalArticleColumn;
    my %FormattedArticleQuery;
    PARAM:
    for my $ArticleParam ( sort keys %{ $Param{Articles} } ) {
        my $Value = $Param{Articles}->{$ArticleParam};
        $ArticleParam =~ /Article_(.*)/;
        my $Column = $1;

        if ( $ArticleTableExternalColumns{$Column} ) {
            $Value = [$Value] if ref $Value ne "ARRAY";
            $ArticleTableExternalColumns{Values}{ $ArticleTableExternalColumns{$Column} } = $Value;
            next PARAM;
        }

        $FormattedArticleQuery{$Column} = $Value;
    }

    my $Articles = $SearchObject->Search(
        Objects     => ['ArticleDataMIME'],
        QueryParams => {
            %FormattedArticleQuery
        },
        Fields => [ ['ArticleID'] ]
    );

    my @ArticleIDs;
    for my $Article ( @{ $Articles->{ArticleDataMIME} } ) {
        my $ArticleID = $Article->{ArticleID};
        push @ArticleIDs, $ArticleID;
    }

    return [] if !@ArticleIDs;

    my $SQL = '
            SELECT ticket_id
            FROM article
            WHERE id IN (' . join( ',', @ArticleIDs ) . ')';

    $SQL .= ' AND ticket_id IN (' . join( ',', @{ $Param{ObjectID} } ) . ')' if $Param{ObjectID};

    for my $Column ( sort keys %{ $ArticleTableExternalColumns{Values} } ) {
        $SQL .= ' AND ' . $Column . ' IN (' . join( ',', @{ $ArticleTableExternalColumns{Values}->{$Column} } ) . ')';
    }

    return if !$DBObject->Prepare(
        SQL => $SQL
    );

    my %TicketIDs;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $TicketIDs{ $Row[0] } = 1;
    }

    my @ObjectIDs = keys %TicketIDs;

    return \@ObjectIDs;
}

=head2 ValidFieldsPrepare()

validates fields for object and return only valid ones

    my %Fields = $SearchTicketESObject->ValidFieldsPrepare(
        Fields      => $Fields, # optional
        Object      => $ObjectName,
        QueryParams => $QueryParams,
    );

=cut

sub ValidFieldsPrepare {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    for my $Name (qw(Object)) {
        if ( !$Param{$Name} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return ();
        }
    }

    my $IndexSearchObject = $Kernel::OM->Get("Kernel::System::Search::Object::Default::$Param{Object}");

    my $Fields      = $IndexSearchObject->{Fields};
    my %ValidFields = ();

    # when no fields are specified use all standard fields
    # (without dynamic fields)
    if ( !IsArrayRefWithData( $Param{Fields} ) ) {
        %ValidFields = %{$Fields};

        return $Self->_PostValidFieldsPrepare(
            ValidFields => \%ValidFields,
            QueryParams => $Param{QueryParams},
        );
    }

    # get dynamic field objects
    my $DynamicFieldObject        = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    for my $ParamField ( @{ $Param{Fields} } ) {
        if ( $Fields->{$ParamField} ) {
            $ValidFields{$ParamField} = $Fields->{$ParamField};
        }

        # get information about dynamic fields if query params
        # starts with specified regexp
        elsif ( $ParamField =~ /^DynamicField_(.+)/ ) {

            # support for static wildcard
            if ( $1 eq '*' ) {

                # get all dynamic fields for the object type Ticket
                my $DynamicFieldList = $DynamicFieldObject->DynamicFieldListGet(
                    ObjectType => 'Ticket',
                );

                DYNAMICFIELD:
                for my $DynamicFieldConfig ( @{$DynamicFieldList} ) {

                    my $ValueStrg = $DynamicFieldBackendObject->ReadableValueRender(
                        DynamicFieldConfig => $DynamicFieldConfig,
                        Value              => '',
                    );

                    # validate each dynamic field
                    next DYNAMICFIELD if !$DynamicFieldConfig;
                    next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);
                    next DYNAMICFIELD if !$DynamicFieldConfig->{Name};

                    my $DynamicFieldColumnName = 'DynamicField_' . $DynamicFieldConfig->{Name};

                    my $FieldValueType = $DynamicFieldBackendObject->TemplateValueTypeGet(
                        DynamicFieldConfig => $DynamicFieldConfig,
                        FieldType          => 'Edit',
                    );

                    my $Type = 'String';

                    if (
                        $DynamicFieldConfig->{FieldType}
                        && $DynamicFieldConfig->{FieldType} eq 'Date'
                        || $DynamicFieldConfig->{FieldType} eq 'DateTime'
                        )
                    {
                        $Type = 'Date';
                    }

                    # set properties that are set in object fields mapping
                    $ValidFields{$DynamicFieldColumnName} = {
                        ColumnName => $DynamicFieldColumnName,
                        ReturnType => $FieldValueType->{$DynamicFieldColumnName} || 'SCALAR',
                        Type       => $Type,
                    };
                }
            }
            else {
                my $DynamicFieldConfig = $DynamicFieldObject->DynamicFieldGet(
                    Name => $1,
                );
                if ( IsHashRefWithData($DynamicFieldConfig) && $DynamicFieldConfig->{Name} ) {

                    my $DynamicFieldColumnName = 'DynamicField_' . $DynamicFieldConfig->{Name};

                    my $FieldValueType = $DynamicFieldBackendObject->TemplateValueTypeGet(
                        DynamicFieldConfig => $DynamicFieldConfig,
                        FieldType          => 'Edit',
                    );

                    my $Type = 'String';

                    if (
                        $DynamicFieldConfig->{FieldType}
                        && $DynamicFieldConfig->{FieldType} eq 'Date'
                        || $DynamicFieldConfig->{FieldType} eq 'DateTime'
                        )
                    {
                        $Type = 'Date';
                    }

                    # set properties that are set in object fields mapping
                    $ValidFields{$DynamicFieldColumnName} = {
                        ColumnName => $DynamicFieldColumnName,
                        ReturnType => $FieldValueType->{$DynamicFieldColumnName} || 'SCALAR',
                        Type       => $Type,
                    };
                }
            }
        }
    }

    return $Self->_PostValidFieldsPrepare(
        ValidFields => \%ValidFields,
        QueryParams => $Param{QueryParams},
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

    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');
    return $SearchChildObject->_PostValidFieldsPrepare(%Param);
}

1;
