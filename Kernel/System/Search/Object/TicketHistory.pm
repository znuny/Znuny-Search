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
    'Kernel::System::Search::Object',
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

    # Define default values. It applies when
    # specified property is empty (undefined).
    my $DefaultValues = {};

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
