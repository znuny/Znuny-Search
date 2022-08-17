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

our @ObjectDependencies = (
    'Kernel::System::Ticket',
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
        TicketID               => 'id',
        TicketNumber           => 'tn',
        Title                  => 'title',
        QueueID                => 'queue_id',
        LockID                 => 'ticket_lock_id',
        TypeID                 => 'type_id',
        ServiceID              => 'service_id',
        SLAID                  => 'sla_id',
        OwnerID                => 'user_id',
        ResponsibleID          => 'responsible_user_id',
        PriorityID             => 'ticket_priority_id',
        StateID                => 'ticket_state_id',
        CustomerID             => 'customer_id',
        CustomerUserID         => 'customer_user_id',
        UnlockTimeout          => 'timeout',
        UntilTime              => 'until_time',
        EscalationTime         => 'escalation_time',
        EscalationUpdateTime   => 'escalation_update_time',
        EscalationResponseTime => 'escalation_response_time',
        EscalationSolutionTime => 'escalation_solution_time',
        ArchiveFlag            => 'archive_flag',
        Created                => 'create_time',
        CreateBy               => 'create_by',
        Changed                => 'change_time',
        ChangeBy               => 'change_by',
    };

    # get default config
    $Self->DefaultConfigGet();

    # load fields with custom field mapping
    $Self->_Load(
        Fields => $FieldMapping,
    );

    return $Self;
}

1;
