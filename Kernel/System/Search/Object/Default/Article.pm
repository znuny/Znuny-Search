# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Default::Article;

use strict;
use warnings;

use parent qw( Kernel::System::Search::Object::Base );
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Main',
    'Kernel::System::Search',
);

=head1 NAME

Kernel::System::Search::Object::Default::Article - common base backend functions for specified object

=head1 DESCRIPTION

This module defines schema and rules for specified object to be used
for fallback or separate engine.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $SearchArticleObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::Article');

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
        "Kernel::System::Search::Object::Engine::$Self->{Engine}::Article",
        Silent => 1,
    );

    return $Kernel::OM->Get("Kernel::System::Search::Object::Engine::$Self->{Engine}::Article") if $Loaded;

    $Self->{Module} = "Kernel::System::Search::Object::Default::Article";

    # specify base config for index
    $Self->{Config} = {
        IndexRealName        => 'article',       # index name on the engine/sql side
        IndexName            => 'Article',       # index name on the api side
        Identifier           => 'ArticleID',     # column name that represents object id in the field mapping
        ChangeTimeColumnName => 'ChangeTime',    # column representing time of updated data entry
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
        ChangeTime => {
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

=head2 DenormalizedArticleFieldsGet()

get all article fields

    my %Fields = $SearchArticleObject->DenormalizedArticleFieldsGet();

=cut

sub DenormalizedArticleFieldsGet {
    my ( $Self, %Param ) = @_;

    return {
        Fields         => $Self->{Fields},
        ExternalFields => $Self->{ExternalFields} || {},
    };
}

1;
