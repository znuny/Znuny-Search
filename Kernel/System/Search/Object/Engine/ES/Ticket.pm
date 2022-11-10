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
    );

    return $Self;
}

sub Search {
    my ( $Self, %Param ) = @_;

    my $SearchObject      = $Kernel::OM->Get('Kernel::System::Search');
    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');
    my $LogObject         = $Kernel::OM->Get('Kernel::System::Log');

    # copy standard param to avoid overwriting on standarization
    my %Params    = %Param;
    my $IndexName = $Param{Objects}->[0];

    # set valid fields for either fallback and advanced search
    # no fields param will get all valid fields for specified object
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
    my $ResultType = $Param{ResultType} || 'ARRAY';

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
            ResultType => $ResultType,
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
                        " \"$Param{ResultType}\" by field: \"$Param{SortBy}\"." .
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
    );
}

sub QuerySearch {
    my ( $Self, %Param ) = @_;

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');

    if ( $Param{UseSQLSearch} || $SearchObject->{Fallback} ) {
        return $Self->FallbackQuerySearch(%Param);
    }

    my $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::$Self->{Config}->{IndexName}");

    my $SearchParams = $IndexQueryObject->_QueryParamsPrepare(
        QueryParams => $Param{QueryParams},
    );

    my $Query = $Param{MappingObject}->Search(
        %Param,
        FieldsDefinition => $Self->{Fields},
        QueryParams      => $SearchParams,
        Object           => $Self->{Config}->{IndexName},
    );

    my $Response = $Param{EngineObject}->QueryExecute(
        Query         => $Query,
        Operation     => 'Search',
        ConnectObject => $Param{ConnectObject},
        Config        => $Param{Config},
        Silent        => $Param{Silent},
    );

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
            Config     => $Param{Config},
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

1;
