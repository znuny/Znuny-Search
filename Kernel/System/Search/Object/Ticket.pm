# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Ticket;

use strict;
use warnings;

use parent qw( Kernel::System::Search::Object::Base );
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Search::Object',
);

=head1 NAME

Kernel::System::Search::Object::Ticket - common base backend functions for "Ticket" index

=head1 DESCRIPTION

TO-DO

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $SearchTicketObject = $Kernel::OM->Get('Kernel::System::Search::Object::Ticket');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # specify base config for index
    $Self->{Config} = {
        IndexRealName => 'ticket',      # engine-wise index name
        IndexName     => 'Ticket',      # backend-wise index name
        Identifier    => 'TicketID',    # column name that represents index object id in the field mapping
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

    # Define default values. It applies when
    # specified column value is empty (undefined).
    my $DefaultValues = {
        ResponsibleID => 1,
        TypeID        => 1,
        ServiceID     => '',
        SLAID         => '',
    };

    # get default config
    $Self->DefaultConfigGet();

    # load fields with custom field mapping
    $Self->_Load(
        Fields        => $FieldMapping,
        DefaultValues => $DefaultValues,
    );

    return $Self;
}

1;
