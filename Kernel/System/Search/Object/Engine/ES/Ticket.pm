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
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicField::Backend',
    'Kernel::System::Group',
    'Kernel::System::Queue',
    'Kernel::System::User',
    'Kernel::System::Search::Object::Query::Ticket',
    'Kernel::System::DB',
    'Kernel::System::Search::Object::Default::Article',
    'Kernel::System::Search::Object::Default::ArticleDataMIME',
    'Kernel::System::Search::Object::Operators',
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

    $Self->{ExternalFields} = {
        GroupID => {
            ColumnName => 'group_id',
            Type       => 'Integer'
        }
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
            # standard ticket fields
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

            # ticket dynamic fields
            DynamicField_Text => 'TextValue',
            DynamicField_Multiselect => [1,2,3],

            # article & article_data_mime fields (denormalized)
            Article_From => 'value',
            Article_To => 'value',
            Article_Cc => 'value',
            Article_Subject => 'value',
            Article_Body => 'value',
            Article_*OtherArticleDataMIMEValues* => 'value',
            Article_SenderTypeID => 'value',
            Article_CommunicationChannelID => 'value',
            Article_IsVisibleForCustomer => 1/0

            # article dynamic fields
            Article_DynamicField_Text => 'TextValue',
            Article_DynamicField_Multiselect => [1,2,3],

            # permission parameters
            GroupID => [1,2,3],
            # when combined witch UserID, there is used "OR" match
            # meaning groups for specified user including groups from
            # "GroupID" will match tickets
            UserID => 1, # no operators support
            Permissions => 'ro' # no operators support, by default "ro" value will be used
                                # permissions for user, therefore should be combined with UserID param

            # additionally there is a possibility to pass names for fields below
            # always pass them in an array
            # can be combined with it's ID's alternative (will match
            # by "AND" operator as any other fields)
            # operators syntax is not supported on those fields
            Queue => ['Misc', 'Junk'],
            SLA         => ['SLA5min'],
            SLAID       => [1],
            Lock        => ['Locked'],
            Type        => ['Unclassified', 'Classifiedd'],
            Service     => ['PremiumService'],
            Owner       => ['root@localhost'],
            Responsible => ['root@localhost'],
            Priority    => ['3 normal'],
            State       => ['open'],
            Customer    => ['customer123', 'customer12345'],

        },
        Fields => [['Ticket_TicketID', 'Ticket_TicketNumber']] # specify field from field mapping
            # to get:
            # - ticket fields (all): [['Ticket_*']]
            # - ticket field (specified): [['Ticket_TicketID', 'Ticket_Title']]
            # - ticket dynamic fields (all): [['Ticket_DynamicField_*']]
            # - ticket dynamic fields (specified): [['Ticket_DynamicField_multiselect', 'Ticket_DynamicField_dropdown']]
            # - ticket "GroupID" field (external field): [['Ticket_GroupID']]
            # - article fields (all): [['Article_*']]
            # - article field (specified): [['Article_Body']]
            # - article dynamic fields (all): [['Article_DynamicField_*']]
            # - article dynamic field (specified): [['Article_DynamicField_Body']]
    );

    Parameter "AdvancedSearchQuery" is not supported on this Object.

=cut

sub Search {
    my ( $Self, %Param ) = @_;

    my $SearchObject      = $Kernel::OM->Get('Kernel::System::Search');
    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');
    my $LogObject         = $Kernel::OM->Get('Kernel::System::Log');
    my $UserObject        = $Kernel::OM->Get('Kernel::System::User');

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

    my $OrderBy = $ObjectData->{OrderBy};
    my $Limit   = $ObjectData->{Limit};
    my $Fields  = $ObjectData->{Fields};

    my $SortBy = $Self->SortParamApply(
        %Param,
        SortBy     => $ObjectData->{SortBy},
        ResultType => $ValidResultType,
    );

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

    my $OperatorModule   = $Kernel::OM->Get("Kernel::System::Search::Object::Operators");
    my $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::$Self->{Config}->{IndexName}");
    my @QueryParamsKey   = keys %{ $Param{QueryParams} };
    my $QueryParams      = $Param{QueryParams};

    # filter & prepare correct parameters
    my $SearchParams = $IndexQueryObject->_QueryParamsPrepare(
        QueryParams => $QueryParams,
    );

    my $SegregatedQueryParams;

    # segregate search params
    for my $SearchParam ( sort keys %{$SearchParams} ) {
        if ( $SearchParam =~ /^Article_DynamicField_(.+)/ ) {
            $SegregatedQueryParams->{ArticleDynamicFields}->{$1} =
                $SearchParams->{$SearchParam};
        }
        elsif ( $SearchParam =~ /^Article_(.+)/ ) {
            $SegregatedQueryParams->{Articles}->{$1} =
                $SearchParams->{$SearchParam};
        }
        else {
            $SegregatedQueryParams->{Ticket}->{$SearchParam} = $SearchParams->{$SearchParam};
        }
    }

    my $Fields               = $Param{Fields}                  || {};
    my $TicketFields         = $Fields->{Ticket}               || {};
    my $TicketDynamicFields  = $Fields->{Ticket_DynamicField}  || {};
    my $ArticleFields        = $Fields->{Article}              || {};
    my $ArticleDynamicFields = $Fields->{Article_DynamicField} || {};

    my %TicketFields  = ( %{$TicketFields},  %{$TicketDynamicFields} );
    my %ArticleFields = ( %{$ArticleFields}, %{$ArticleDynamicFields} );

    # build standard ticket query
    my $Query = $Param{MappingObject}->Search(
        %Param,
        Fields      => \%TicketFields,
        QueryParams => $SegregatedQueryParams->{Ticket},
        Object      => $Self->{Config}->{IndexName},
        _Source     => 1,
    );

    my $ArticleSearchParams              = $SegregatedQueryParams->{Articles};
    my $ArticleDynamicFieldsSearchParams = $SegregatedQueryParams->{ArticleDynamicFields};

    my $ArticleNestedQuery = {
        nested => {
            path       => 'Articles',
            inner_hits => {
                _source => 'false',
            }
        }
    };

    # check if there was passed any article/article dynamic fields
    # in "Fields" param
    if ( keys %ArticleFields ) {

        # prepare query part for children fields to retrieve
        $ArticleNestedQuery->{nested}->{inner_hits}->{_source} = [];
        for my $ArticleField ( sort keys %ArticleFields ) {
            push @{ $ArticleNestedQuery->{nested}->{inner_hits}->{_source} }, 'Articles.' . $ArticleField;
        }
    }

    # build and append article query if needed
    if ( IsHashRefWithData($ArticleSearchParams) ) {

        my %AllArticleFields = $Self->_DenormalizedArticleFieldsGet();

        # check if field exists in the mapping
        for my $ArticleQueryParam ( sort keys %{$ArticleSearchParams} ) {
            delete $ArticleSearchParams->{$ArticleQueryParam} if ( !$AllArticleFields{$ArticleQueryParam} );
        }

        # continue only if any field was validated
        if ( IsHashRefWithData($ArticleSearchParams) ) {
            for my $ArticleField ( sort keys %{$ArticleSearchParams} ) {

                for my $OperatorData ( @{ $ArticleSearchParams->{$ArticleField}->{Query} } ) {
                    my $OperatorValue        = $OperatorData->{Value};
                    my $ArticleFieldForQuery = 'Articles.' . $ArticleField;

                    # build query
                    my $Result = $OperatorModule->OperatorQueryGet(
                        Field      => $ArticleFieldForQuery,
                        ReturnType => $OperatorData->{ReturnType},
                        Value      => $OperatorValue,
                        Operator   => $OperatorData->{Operator},
                        Object     => 'Ticket',
                    );

                    my $ArticleQuery = $Result->{Query};

                    # append query
                    push @{ $ArticleNestedQuery->{nested}{query}{bool}{ $Result->{Section} } }, $ArticleQuery;
                }
            }
        }
    }

    # build and append article dynamic fields query if needed
    if ( IsHashRefWithData($ArticleDynamicFieldsSearchParams) ) {
        my $DynamicFieldObject        = $Kernel::OM->Get('Kernel::System::DynamicField');
        my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

        my %IgnoreDynamicFieldProcessing;

        # search for event (live indexation) data
        if ( $Param{Event} && $Param{Event}{Type} ) {
            my $NewName = $Param{Event}{Data}{DynamicField}{Article}{New}{Name};

            # ignore dynamic field further processing as it changed it's name
            # on the OTRS side when updating, but there is a need to search for
            # old name in ES engine
            if ( $Param{Event}{Type} eq 'DynamicFieldUpdate' ) {
                my $OldName = $Param{Event}{Data}{DynamicField}{Article}{Old}{Name};

                if ( $NewName && $OldName && $ArticleDynamicFieldsSearchParams->{$OldName} ) {
                    $IgnoreDynamicFieldProcessing{$OldName} = 1;
                }
            }

            # ignore dynamic field further processing as it does not exists
            # on the OTRS side when removing
            elsif ( $Param{Event}{Type} eq 'DynamicFieldDelete' ) {

                if ( $NewName && $ArticleDynamicFieldsSearchParams->{$NewName} ) {
                    $IgnoreDynamicFieldProcessing{$NewName} = 1;
                }
            }
        }

        DYNAMIC_FIELD:
        for my $ArticleDynamicFieldName ( sort keys %{$ArticleDynamicFieldsSearchParams} ) {

            my $DynamicFieldConfig;
            my $FieldValueType;

            if ( !$IgnoreDynamicFieldProcessing{$ArticleDynamicFieldName} ) {
                $DynamicFieldConfig = $DynamicFieldObject->DynamicFieldGet(
                    Name => $ArticleDynamicFieldName,
                );
                next DYNAMIC_FIELD if !IsHashRefWithData($DynamicFieldConfig);

                $FieldValueType = $DynamicFieldBackendObject->TemplateValueTypeGet(
                    DynamicFieldConfig => $DynamicFieldConfig,
                    FieldType          => 'Edit',
                );
            }

            my $ReturnType = $FieldValueType->{"DynamicField_$ArticleDynamicFieldName"} || 'SCALAR';

            for my $OperatorData ( @{ $ArticleDynamicFieldsSearchParams->{$ArticleDynamicFieldName}->{Query} } ) {

                my $OperatorValue        = $OperatorData->{Value};
                my $ArticleFieldForQuery = 'Articles.DynamicField_' . $ArticleDynamicFieldName;

                my $Result = $OperatorModule->OperatorQueryGet(
                    Field      => $ArticleFieldForQuery,
                    ReturnType => $ReturnType,
                    Value      => $OperatorValue,
                    Operator   => $OperatorData->{Operator},
                    Object     => 'Ticket',
                );

                my $ArticleQuery = $Result->{Query};

                push @{ $ArticleNestedQuery->{nested}{query}{bool}{ $Result->{Section} } }, $ArticleQuery;
            }
        }
    }

    my $NestedFieldsGet      = 1;
    my $NestedQueryBuilt     = IsHashRefWithData( $ArticleNestedQuery->{nested}{query} ) ? 1 : 0;
    my $NestedFieldsToSelect = IsArrayRefWithData( $ArticleNestedQuery->{nested}->{inner_hits}->{_source} ) ? 1 : 0;

    # there is a requirement from ES that nested query needs
    # to be specified when selecting nested fields
    if ( $NestedFieldsToSelect && !$NestedQueryBuilt ) {
        $ArticleNestedQuery->{nested}{query}->{match_all} = {};
    }

    if ( $ArticleNestedQuery->{nested}{query} ) {
        push @{ $Query->{Body}{query}{bool}{must} }, $ArticleNestedQuery;
    }

    if ( !$NestedFieldsToSelect && !$NestedQueryBuilt ) {
        $NestedFieldsGet = 0;
    }

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
        Fields          => \%TicketFields,
        NestedFieldsGet => $NestedFieldsGet,
        Result          => $Response,
        IndexName       => 'Ticket',
        Operation       => 'Search',
        ResultType      => $Param{ResultType} || 'ARRAY',
        QueryData       => {
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

    my $Result = {
        Ticket => $Self->Fallback( %Param, Fields => $Param{Fields}->{Ticket} ) // []
    };

    # format reponse per index
    my $FormattedResult = $SearchObject->SearchFormat(
        Result     => $Result,
        Config     => $Param{GlobalConfig},
        IndexName  => $Self->{Config}->{IndexName},
        Operation  => "Search",
        ResultType => $Param{ResultType} || 'ARRAY',
        Fallback   => 1,
        Silent     => $Param{Silent},
        Fields     => $Param{Fields}->{Ticket},
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

    return $Self->SUPER::ObjectIndexAdd(
        %Param,
    );
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

    return $Self->SUPER::ObjectIndexSet(
        %Param,
    );
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

    return $Self->SUPER::ObjectIndexUpdate(
        %Param,
    );
}

=head2 IndexMappingSet()

create query for index mapping set operation

    my $Result = $SearchQueryObject->IndexMappingSet(
        MappingObject   => $MappingObject,
    );

=cut

sub IndexMappingSet {
    my ( $Self, %Param ) = @_;

    return if !$Param{MappingObject};

    my $QueryTicketObject = $Kernel::OM->Get('Kernel::System::Search::Object::Query::Ticket');

    my $MappingQuery = $QueryTicketObject->IndexMappingSet(
        MappingObject => $Param{MappingObject},
    );

    return if !IsHashRefWithData( $MappingQuery->{Body}->{properties} );

    my $DataTypes = $Param{MappingObject}->MappingDataTypesGet();

    my $SearchArticleObject         = $Kernel::OM->Get('Kernel::System::Search::Object::Default::Article');
    my $SearchArticleDataMIMEObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::ArticleDataMIME');
    my $ArticleFields               = $SearchArticleObject->{Fields};
    my $ArticleDataMIMEFields       = $SearchArticleDataMIMEObject->{Fields};

    # add nested type relation for articles && article data mime tables
    if ( IsHashRefWithData($ArticleFields) && IsHashRefWithData($ArticleDataMIMEFields) ) {
        $MappingQuery->{Body}->{properties}->{Articles} = {
            type => 'nested',
        };

        for my $ArticleFieldName ( sort keys %{$ArticleFields} ) {
            $MappingQuery->{Body}->{properties}->{Articles}->{properties}->{$ArticleFieldName}
                = $DataTypes->{ $ArticleFields->{$ArticleFieldName}->{Type} };
        }
        for my $ArticleFieldName ( sort keys %{$ArticleDataMIMEFields} ) {
            $MappingQuery->{Body}->{properties}->{Articles}->{properties}->{$ArticleFieldName}
                = $DataTypes->{ $ArticleDataMIMEFields->{$ArticleFieldName}->{Type} };
        }
    }

    my $Response = $Param{EngineObject}->QueryExecute(
        %Param,
        Query         => $MappingQuery,
        Operation     => "IndexMappingSet",
        ConnectObject => $Param{ConnectObject},
    );

    return $Param{MappingObject}->IndexMappingSetFormat(
        %Param,
        Result => $Response,
        Config => $Param{Config},
    );
}

=head2 SQLObjectSearch()

TO-DO add support for child "Field" parameters.

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

    my $GroupObject = $Kernel::OM->Get('Kernel::System::Group');

    my $QueryParams = $Param{QueryParams};
    my $Fields      = $Param{Fields};
    my $GroupField;

    # fields passed as hash needs to be
    # converted into array due to further calculations
    if ( IsHashRefWithData($Fields) ) {
        my %Fields = %{ $Param{Fields} };
        undef $Fields;
        @{$Fields} = keys %{ $Param{Fields} };
    }
    elsif ( !$Fields || !IsArrayRefWithData($Fields) ) {

        # no fields specified will return response with standard fields
        # plus denormalized group id
        @{$Fields} = keys %{ $Self->{Fields} };
        $GroupField = 'GroupID';
    }

    my @GroupQueryParam = ();

    # delete groupid, userid, permissions from queryparams/fields
    # as those are not present in the ticket table
    # support them after standard sql search
    if ( IsArrayRefWithData( $QueryParams->{GroupID} ) ) {
        my $GroupIDs = delete $QueryParams->{GroupID};
        @GroupQueryParam = @{$GroupIDs};
    }
    elsif ( $QueryParams->{GroupID} ) {
        delete $QueryParams->{GroupID};
    }
    my $UserIDQueryParam      = delete $QueryParams->{UserID};
    my $PermissionsQueryParam = delete $QueryParams->{Permissions};

    if ( !$GroupField ) {
        FIELDS:
        for ( my $i = 0; $i < scalar @{$Fields}; $i++ ) {
            if ( $Fields->[$i] eq 'GroupID' ) {
                $GroupField = delete $Fields->[$i];
                @{$Fields} = grep {$_} @{$Fields};
                last FIELDS;
            }
        }
    }

    # perform default sql object search
    my $SQLSearchResult = $Self->SUPER::SQLObjectSearch(
        %Param,
        QueryParams => $QueryParams,
        Fields      => $Fields,
    );

    return $SQLSearchResult if !IsArrayRefWithData($SQLSearchResult);

    my $QueueObject = $Kernel::OM->Get('Kernel::System::Queue');
    my $DBObject    = $Kernel::OM->Get('Kernel::System::DB');

    # get dynamic field objects
    my $DynamicFieldObject        = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    # get article objects
    my $SearchArticleObject         = $Kernel::OM->Get('Kernel::System::Search::Object::Default::Article');
    my $SearchArticleDataMIMEObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::ArticleDataMIME');

    # get all dynamic fields for the object type Ticket
    my $TicketDynamicFieldList = $DynamicFieldObject->DynamicFieldListGet(
        ObjectType => 'Ticket'
    );

    # check all configured article dynamic fields
    my $ArticleDynamicFields = $DynamicFieldObject->DynamicFieldListGet(
        ObjectType => 'Article',
    );

    TICKET:
    for my $Ticket ( @{$SQLSearchResult} ) {
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{$TicketDynamicFieldList} ) {

            # get the current value for each dynamic field
            my $Value = $DynamicFieldBackendObject->ValueGet(
                DynamicFieldConfig => $DynamicFieldConfig,
                ObjectID           => $Ticket->{TicketID},
            );

            # set the dynamic field name and value into the ticket hash
            # only if value is defined
            if ( defined $Value ) {
                $Ticket->{ 'DynamicField_' . $DynamicFieldConfig->{Name} } = $Value;
            }
        }

        # search articles for specified ticket id
        my $Articles = $SearchArticleObject->SQLObjectSearch(
            QueryParams => {
                TicketID => $Ticket->{TicketID},
            }
        ) || [];

        for my $Article ( @{$Articles} ) {
            my $ArticlesDataMIME = $SearchArticleDataMIMEObject->SQLObjectSearch(
                QueryParams => {
                    ArticleID => $Article->{ArticleID},
                }
            ) || [];

            my $ArticleDataMIMERow = $ArticlesDataMIME->[0];

            %{$Article} = ( %{$Article}, %{$ArticleDataMIMERow} );

            # add article dynamic fields
            DYNAMICFIELD:
            for my $DynamicFieldConfig ( @{$ArticleDynamicFields} ) {

                # get the current value for each dynamic field
                my $Value = $DynamicFieldBackendObject->ValueGet(
                    DynamicFieldConfig => $DynamicFieldConfig,
                    ObjectID           => $Article->{ArticleID},
                );

                # set the dynamic field name and value into the ticket hash
                # only if value is defined
                if ( defined $Value ) {
                    $Article->{ 'DynamicField_' . $DynamicFieldConfig->{Name} } = $Value;
                }
            }
        }

        $Ticket->{Articles} = $Articles;
    }

    # support user id, group id, permissions params
    if ( $GroupField || scalar(@GroupQueryParam) || $UserIDQueryParam ) {
        my @GroupFilteredResult;

        # support permissions
        if ($UserIDQueryParam) {

            # get users groups
            my %GroupList = $GroupObject->PermissionUserGet(
                UserID => $UserIDQueryParam,
                Type   => $PermissionsQueryParam || 'ro',
            );

            # push user groups on the same array as groups from "GroupID" parameter
            push @GroupQueryParam, keys %GroupList;
        }

        for my $Row ( @{$SQLSearchResult} ) {
            if ( $Row->{QueueID} ) {

                # do not use standard queue get function as it
                # would return cached (old) queue group id
                # on queue update events
                # optionally to-do - can be optimized in a way that a parameter
                # will decide if we can use cached response
                return if !$DBObject->Prepare(
                    SQL   => "SELECT group_id FROM queue WHERE id = $Row->{QueueID}",
                    Limit => 1,
                );

                my @Data         = $DBObject->FetchrowArray();
                my $QueueGroupID = $Data[0];

                # check if ticket exists in specified groups of user/group params
                if ( !scalar @GroupQueryParam || grep { $_ == $QueueGroupID } @GroupQueryParam ) {

                    # additionally append GroupID to the response
                    if ($GroupField) {
                        $Row->{GroupID} = $QueueGroupID;
                    }
                    push @GroupFilteredResult, $Row;
                }

            }
        }
        return \@GroupFilteredResult;
    }
    return $SQLSearchResult;
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

    my $Fields         = $IndexSearchObject->{Fields};
    my $ExternalFields = $IndexSearchObject->{ExternalFields};

    my %ValidFields = ();

    # when no fields are specified use all standard fields
    # (without dynamic fields)
    if ( !IsArrayRefWithData( $Param{Fields} ) ) {
        %ValidFields = (
            Ticket => { %{$Fields}, %{$ExternalFields} }
        );

        return $Self->_PostValidFieldsPrepare(
            ValidFields => \%ValidFields,
            QueryParams => $Param{QueryParams},
        );
    }

    # get dynamic field objects
    my $DynamicFieldObject        = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
    my %AllArticleFields          = $Self->_DenormalizedArticleFieldsGet();

    for my $ParamField ( @{ $Param{Fields} } ) {

        # get information about field types if field
        # matches specified regexp
        if ( $ParamField =~ /^(?:Ticket_DynamicField_(.+))|(?:Article_DynamicField_(.+))/ ) {
            if ( $1 && $1 eq '*' || $2 && $2 eq '*' ) {

                my $ObjectType;
                my $DFColumnNamePre = '';
                if ( $ParamField =~ /^Article/ ) {
                    $ObjectType = 'Article';
                }
                else {
                    $ObjectType = 'Ticket';
                }

                # get all dynamic fields for object type "Ticket" or "Article"
                my $DynamicFieldList = $DynamicFieldObject->DynamicFieldListGet(
                    ObjectType => $ObjectType,
                );

                DYNAMICFIELD:
                for my $DynamicFieldConfig ( @{$DynamicFieldList} ) {

                    my $DynamicFieldColumnName = $DFColumnNamePre . 'DynamicField_' . $DynamicFieldConfig->{Name};

                    # get return type for dynamic field
                    my $FieldValueType = $DynamicFieldBackendObject->TemplateValueTypeGet(
                        DynamicFieldConfig => $DynamicFieldConfig,
                        FieldType          => 'Edit',
                    );

                    # set type of field
                    my $Type = 'String';

                    if (
                        $DynamicFieldConfig->{FieldType}
                        && $DynamicFieldConfig->{FieldType} eq 'Date'
                        || $DynamicFieldConfig->{FieldType} eq 'DateTime'
                        )
                    {
                        $Type = 'Date';
                    }

                    # apply properties that are set in object fields mapping
                    $ValidFields{ $ObjectType . '_DynamicField' }->{$DynamicFieldColumnName} = {
                        ColumnName => $DynamicFieldColumnName,
                        ReturnType => $FieldValueType->{$DynamicFieldColumnName} || 'SCALAR',
                        Type       => $Type,
                    };
                }
            }
            else {
                # get single dynamic field config
                my $DynamicFieldConfig = $DynamicFieldObject->DynamicFieldGet(
                    Name => $1 || $2,
                );

                # get object - "Ticket" or "Article"
                my $ObjectType = $DynamicFieldConfig->{ObjectType};

                if ( IsHashRefWithData($DynamicFieldConfig) && $DynamicFieldConfig->{Name} ) {

                    my $DynamicFieldColumnName;

                    if ( $ObjectType eq 'Article' ) {
                        $DynamicFieldColumnName = 'DynamicField_' . $DynamicFieldConfig->{Name};
                    }
                    else {
                        $DynamicFieldColumnName = 'DynamicField_' . $DynamicFieldConfig->{Name};
                    }

                    # get return type for dynamic field
                    my $FieldValueType = $DynamicFieldBackendObject->TemplateValueTypeGet(
                        DynamicFieldConfig => $DynamicFieldConfig,
                        FieldType          => 'Edit',
                    );

                    # set type of field
                    my $Type = 'String';

                    if (
                        $DynamicFieldConfig->{FieldType}
                        && $DynamicFieldConfig->{FieldType} eq 'Date'
                        || $DynamicFieldConfig->{FieldType} eq 'DateTime'
                        )
                    {
                        $Type = 'Date';
                    }

                    # apply properties that are set in object fields mapping
                    $ValidFields{ $ObjectType . '_DynamicField' }->{$DynamicFieldColumnName} = {
                        ColumnName => $DynamicFieldColumnName,
                        ReturnType => $FieldValueType->{$DynamicFieldColumnName} || 'SCALAR',
                        Type       => $Type,
                    };
                }
            }
        }

        # apply "Ticket" fields
        elsif ( $ParamField =~ /^Ticket_(.+)$/ ) {

            # get single "Ticket" field
            if ( $Fields->{$1} ) {
                $ValidFields{Ticket}->{$1} = $Fields->{$1};
            }

            # get single field from external fields
            # that is for example "GroupID"
            elsif ( $ExternalFields->{$1} ) {
                $ValidFields{Ticket}->{$1} = $ExternalFields->{$1};
            }

            # get all "Ticket" fields
            elsif ( $1 eq '*' ) {
                my $TicketFields = $ValidFields{Ticket} // {};
                %{ $ValidFields{Ticket} } = ( %{$Fields}, %{$ExternalFields}, %{$TicketFields} );
            }
        }

        # apply "Article" fields
        elsif ( $ParamField =~ /^Article_(.+)/ ) {

            # get single "Article" field
            if ( $AllArticleFields{$1} ) {
                $ValidFields{Article}{$1} = $AllArticleFields{$1};
            }

            # get all "Article" fields
            elsif ( $1 && $1 eq '*' ) {
                for my $ArticleField ( sort keys %AllArticleFields ) {
                    $ValidFields{Article}{$ArticleField} = $AllArticleFields{$ArticleField};
                }
            }
        }
    }

    return $Self->_PostValidFieldsPrepare(
        ValidFields => \%ValidFields,
        QueryParams => $Param{QueryParams},
    );
}

=head2 _DenormalizedArticleFieldsGet()

get all article fields including article data mime

    my %Fields = $SearchTicketESObject->_DenormalizedArticleFieldsGet();

=cut

sub _DenormalizedArticleFieldsGet {
    my ( $Self, %Param ) = @_;

    my $SearchArticleObject         = $Kernel::OM->Get('Kernel::System::Search::Object::Default::Article');
    my $SearchArticleDataMIMEObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::ArticleDataMIME');

    my $ArticleFields         = $SearchArticleObject->{Fields};
    my $ArticleDataMIMEFields = $SearchArticleDataMIMEObject->{Fields};

    my %AllArticleFields = ( %{$ArticleFields}, %{$ArticleDataMIMEFields} );

    return %AllArticleFields;
}

=head2 _PostValidFieldsPrepare()

set fields return type if not specified

    my %Fields = $SearchTicketESObject->_PostValidFieldsPrepare(
        ValidFields => $ValidFields,
    );

=cut

sub _PostValidFieldsPrepare {
    my ( $Self, %Param ) = @_;

    return () if !IsHashRefWithData( $Param{ValidFields} );

    my %ValidFields = %{ $Param{ValidFields} };

    for my $Type (qw(Ticket Article)) {
        for my $Field ( sort keys %ValidFields ) {
            if ( $ValidFields{$Type}->{$Field} ) {
                $ValidFields{$Type}->{$Field}->{ReturnType} = 'SCALAR' if !$ValidFields{$Type}->{$Field}->{ReturnType};
            }
        }
    }

    return %ValidFields;
}

1;
