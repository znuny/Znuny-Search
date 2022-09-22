# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Article;

use strict;
use warnings;

use parent qw( Kernel::System::Search::Object::Base );
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Search::Object',
);

=head1 NAME

Kernel::System::Search::Object::Article - common base backend functions for specified object

=head1 DESCRIPTION

This module defines schema and rules for specified object to be used
for fallback or separate engine.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $SearchArticleObject = $Kernel::OM->Get('Kernel::System::Search::Object::Article');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # specify base config for index
    $Self->{Config} = {
        IndexRealName => 'article',      # index name on the engine/sql side
        IndexName     => 'Article',      # index name on the api side
        Identifier    => 'ArticleID',    # column name that represents object id in the field mapping
    };

    # define schema for data
    my $FieldMapping = {
        ArticleID => {
            ColumnName => 'id',
            Type       => 'Integer'
        },
        TicketID => {
            ColumnName => 'ticket_id',
            Type       => 'Integer'
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
        SearchIndexNeedsRebuild => {
            ColumnName => 'search_index_needs_rebuild',
            Type       => 'Integer'
        },
        InsertFingerprint => {
            ColumnName => 'insert_fingerprint',
            Type       => 'String'
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
