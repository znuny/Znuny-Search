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

use parent qw( Kernel::System::Search::Object::Ticket );
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Search::Object',
    'Kernel::System::Log',
    'Kernel::System::Search',
    'Kernel::System::DB',
    'Kernel::System::Search::Object::Operators',
    'Kernel::System::Search::Object::Query::DynamicFieldValue',
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

    $Self->{Module} = "Kernel::System::Search::Object::Engine::ES::Ticket";

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
            DynamicField_Name1 => 'value1',
            DynamicField_Name2 => 'value2',
        }
    );

=cut

sub Search {
    my ( $Self, %Param ) = @_;

    my $SearchObject      = $Kernel::OM->Get('Kernel::System::Search');
    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');
    my $LogObject         = $Kernel::OM->Get('Kernel::System::Log');

    # copy standard param to avoid overwriting on standarization
    my %Params    = %Param;
    my $IndexName = $Param{Objects}->[0];

    # set valid fields for either fallback and advanced search
    # no fields param passed will get all valid fields for specified object
    $Param{Fields}->[ $Param{Counter} ] = $SearchChildObject->ValidFieldsGet(
        Fields => $Param{Fields}->[ $Param{Counter} ],
        Object => $IndexName,
    );

    if ( !IsArrayRefWithData( $Param{Fields}->[ $Param{Counter} ] ) ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Wrong fields in search param!"
        );
        return;
    }

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

    my $OrderBy;
    my $SortByCheck;
    my $Limit;
    my $Fields;

    if ( IsArrayRefWithData( $Param{SortBy} ) ) {
        $SortByCheck = $Param{SortBy}->[ $Param{Counter} ];
    }
    elsif ( $Param{SortBy} ) {
        $SortByCheck = $Param{SortBy};
    }
    if ( IsArrayRefWithData( $Param{OrderBy} ) ) {
        $OrderBy = $Param{OrderBy}->[ $Param{Counter} ];
    }
    elsif ($OrderBy) {
        $OrderBy = $Param{OrderBy};
    }
    if ( IsArrayRefWithData( $Param{Limit} ) ) {
        $Limit = $Param{Limit}->[ $Param{Counter} ];
    }
    elsif ($Limit) {
        $Limit = $Param{Limit};
    }
    if ( IsArrayRefWithData( $Param{Fields} ) ) {
        $Fields = $Param{Fields}->[ $Param{Counter} ];
    }
    my $SortBy;
    if (
        $SortByCheck && $Self->{Fields}->{$SortByCheck}
        )
    {
        my $Sortable = $Self->IsSortableResultType(
            ResultType => $ValidResultType,
        );

        if ($Sortable) {

            # change into real column name
            $SortBy = $Self->{Fields}->{$SortByCheck};
        }
        else {
            if ( !$Param{Silent} ) {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "Can't sort index: \"$Self->{Config}->{IndexName}\" with result type:" .
                        " \"$Param{ResultType}\" by field: \"$SortByCheck\"." .
                        " Specified result type is not sortable!\n" .
                        " Sort operation won't be applied."
                );
            }
        }
    }

    return $Self->QuerySearch(
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

=head2 QuerySearch()

perform actual search

    my $Result = $SearchTicketESObject->QuerySearch(
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

sub QuerySearch {
    my ( $Self, %Param ) = @_;

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');

    if ( $Param{UseSQLSearch} || $SearchObject->{Fallback} ) {
        return $Self->FallbackQuerySearch(%Param);
    }

    my @DynamicFieldsParam = keys %{ $Param{QueryParams} };
    my %DynamicFieldsParam = map { $_ => $Param{QueryParams}->{$_} } grep { $_ =~ /DynamicField_/ } @DynamicFieldsParam;

    if ( keys %DynamicFieldsParam ) {
        my $ObjectIDs = $Self->_SearchByDynamicFields(
            DynamicFields => \%DynamicFieldsParam,
            ObjectID      => $Param{QueryParams}->{TicketID},
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

        $Param{QueryParams}->{TicketID} = $ObjectIDs;
    }

    my $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::$Self->{Config}->{IndexName}");

    # filter & prepare correct parameters
    my $SearchParams = $IndexQueryObject->_QueryParamsPrepare(
        QueryParams => $Param{QueryParams},
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

=head2 FallbackQuerySearch()

execute full fallback for searching tickets

notice: fall-back does not support searching by dynamic fields yet

    my $FunctionResult = $Object->FallbackQuerySearch(
        %Params,
    );

=cut

sub FallbackQuerySearch {
    my ( $Self, %Param ) = @_;

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');

    my $Result = {
        Ticket => $Self->Fallback(%Param)
    };

    if ($Result) {

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

        return $FormattedResult;
    }

    return {};
}

sub _SearchByDynamicFields {
    my ( $Self, %Param ) = @_;

    return if !IsHashRefWithData( $Param{DynamicFields} ) && !$Param{ObjectID};

    my $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::DynamicFieldValue");

    my %Query = ();

    my $SQL                  = 'SELECT id, name from dynamic_field WHERE 1=1';
    my $SQLWhereColumnName   = ' AND object_type = "Ticket"';
    my $SQLWhereDynamicField = '';
    my @BindValues;

    my %FieldsData;
    my $SQLWhereToAppend = 'AND (';
    my $AggrCount        = 0;
    DYNAMIC_FIELD:
    for my $DynamicField ( sort keys %{ $Param{DynamicFields} } ) {
        my $DynamicFieldName;

        $DynamicField =~ /DynamicField\_(.+)/;
        next DYNAMIC_FIELD if !$1;

        $DynamicFieldName = $1;
        $SQLWhereDynamicField .= " $SQLWhereToAppend name = ? ";
        $SQLWhereToAppend = 'OR ';
        $AggrCount++;
        push @BindValues, \$DynamicFieldName;
    }

    $SQLWhereDynamicField .= ')' if $SQLWhereDynamicField;
    my $SQLWhere = $SQLWhereColumnName . $SQLWhereDynamicField;
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    return if !$DBObject->Prepare(
        SQL  => $SQL . $SQLWhere,
        Bind => \@BindValues,
    );

    while ( my @Row = $DBObject->FetchrowArray() ) {
        my $Name = $Row[1];
        $FieldsData{ $Row[0] } = $Param{DynamicFields}->{ 'DynamicField_' . $Name };
    }

    # aggregation is not optimal but used for now as there is no
    # other way to filter tickets by dynamic fields without ES relations
    $Query{Body}->{aggs}->{"ObjectID"}->{terms}->{field}         = 'object_id';
    $Query{Body}->{aggs}->{"ObjectID"}->{terms}->{min_doc_count} = $AggrCount;
    $Query{Body}->{size}                                         = 0;

    my $OperatorModule = $Kernel::OM->Get("Kernel::System::Search::Object::Operators");
    my $Counter        = 0;
    my %ObjectIDQueryBody;

    # apply ticket id as object id from main query
    if ( $Param{ObjectID} ) {

        my $OperatorData = $IndexQueryObject->_QueryParamsPrepare(
            QueryParams => {
                ObjectID => $Param{ObjectID},
            }
        );

        for my $OperatorData ( @{ $OperatorData->{ObjectID}->{Query} } ) {
            my $OperatorValue = $OperatorData->{Value};

            my $Result = $OperatorModule->OperatorQueryGet(
                Field    => 'object_id',
                Value    => $OperatorValue,
                Operator => $OperatorData->{Operator},
                Object   => 'DynamicFieldValue',
            );

            push @{ $ObjectIDQueryBody{ $Result->{Section} } }, $Result->{Query};
        }

        push @{ $Query{Body}->{query}->{bool}->{must} },
            {
            bool => {
                %ObjectIDQueryBody,
            }
            };
    }

    # apply all dynami field queries to ES
    for my $DynamicFieldID ( sort keys %FieldsData ) {
        my $OperatorData = $IndexQueryObject->_QueryParamsPrepare(
            QueryParams => {
                Value => $FieldsData{$DynamicFieldID},
            }
        );

        my %MainQueryBody =
            (
            must =>
                [
                {
                    match => {
                        field_id => {
                            query => $DynamicFieldID,
                        }
                    }
                },
                ]
            );

        for my $OperatorData ( @{ $OperatorData->{Value}->{Query} } ) {
            my $OperatorValue = $OperatorData->{Value};

            my $Result = $OperatorModule->OperatorQueryGet(
                Field    => 'value',
                Value    => $OperatorValue,
                Operator => $OperatorData->{Operator},
                Object   => 'DynamicFieldValue',
            );

            push @{ $MainQueryBody{ $Result->{Section} } }, $Result->{Query};
        }

        # apply as first index to the query bool
        # just in case object id was sent here (to not overwrite it)
        push @{ $Query{Body}->{query}->{bool}->{must}->[1]->{bool}->{should} },
            {
            bool => {
                %MainQueryBody,
            }
            };
    }

    # set base query params
    $Query{Method} = 'GET';
    $Query{Path}   = '/dynamic_field_value/_search';

    my $Response = $Param{EngineObject}->QueryExecute(
        Query         => \%Query,
        Operation     => 'Search',
        ConnectObject => $Param{ConnectObject},
        Silent        => $Param{Silent},
    );

    my $Buckets   = $Response->{aggregations}->{ObjectID}->{buckets};
    my @ObjectIDs = ();

    if ( IsArrayRefWithData($Buckets) ) {
        @ObjectIDs = map { $_->{key} } @{$Buckets};
    }

    return \@ObjectIDs;
}

1;
