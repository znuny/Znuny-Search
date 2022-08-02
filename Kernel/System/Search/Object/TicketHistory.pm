# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::TicketHistory;

use strict;
use warnings;

use parent qw( Kernel::System::Search::Object::Base );

our @ObjectDependencies = (
    'Kernel::System::DB',
);

=head1 NAME

Kernel::System::Search::Object::TicketHistory - common base backend functions for "TicketHistory" index

=head1 DESCRIPTION

TO-DO

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $SearchTicketHistoryObject = $Kernel::OM->Get('Kernel::System::Search::Object::TicketHistory');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # specify base config for index
    $Self->{Config} = {
        IndexRealName => 'ticket_history',     # engine-wise index name
        IndexName     => 'TicketHistory',      # backend-wise index name
        Identifier    => 'TicketHistoryID',    # column name that represents index object id in the field mapping
    };

    # define schema for data
    my $FieldMapping = {
        TicketHistoryID => 'id',
        Name            => 'name',
        HistoryTypeID   => 'history_type_id',
        TicketID        => 'ticket_id',
        ArticleID       => 'article_id',
        TypeID          => 'type_id',
        QueueID         => 'queue_id',
        OwnerID         => 'owner_id',
        PriorityID      => 'priority_id',
        StateID         => 'state_id',
        Created         => 'create_time',
        CreateBy        => 'create_by',
        Changed         => 'change_time',
        ChangeBy        => 'change_by',
    };

    # load custom field mapping
    %{$FieldMapping} = ( %{$FieldMapping}, %{ $Self->CustomFieldsConfig() } );

    $Self->{Fields} = $FieldMapping;

    return $Self;
}

=head2 ObjectListIDs()

return all sql data of object ids

    my $ResultIDs = $SearchTicketHistoryObject->ObjectListIDs();

=cut

sub ObjectListIDs {
    my ( $Self, %Param ) = @_;

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    $DBObject->Prepare(
        SQL => "SELECT id FROM ticket_history ORDER BY change_time DESC",
    );

    my @TicketHistoryIDs;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        push @TicketHistoryIDs, $Row[0];
    }

    return \@TicketHistoryIDs;
}

1;
