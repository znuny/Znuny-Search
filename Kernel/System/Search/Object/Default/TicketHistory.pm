# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Default::TicketHistory;

use strict;
use warnings;

use parent qw( Kernel::System::Search::Object::Base );

our @ObjectDependencies = (
    'Kernel::System::Main',
    'Kernel::System::Search',
);

=head1 NAME

Kernel::System::Search::Object::Default::TicketHistory - common base backend functions for specified object

=head1 DESCRIPTION

This module defines schema and rules for specified object to be used
for fallback or separate engine.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $SearchTicketHistoryObject = $Kernel::OM->Get('Kernel::System::Search::Default::Object::TicketHistory');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check for engine package for this object
    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');
    my $MainObject   = $Kernel::OM->Get('Kernel::System::Main');

    $Self->{Engine} = $SearchObject->{Config}->{ActiveEngine} || 'ES';

    my $Loaded = $MainObject->Require(
        "Kernel::System::Search::Object::Engine::$Self->{Engine}::TicketHistory",
        Silent => 1,
    );

    return $Kernel::OM->Get("Kernel::System::Search::Object::Engine::$Self->{Engine}::TicketHistory") if $Loaded;

    $Self->{Module} = "Kernel::System::Search::Object::Default::TicketHistory";

    # specify base config for index
    $Self->{Config} = {
        IndexRealName => 'ticket_history',     # index name on the engine/sql side
        IndexName     => 'TicketHistory',      # index name on the api side
        Identifier    => 'TicketHistoryID',    # column name that represents object id in the field mapping
    };

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

1;
