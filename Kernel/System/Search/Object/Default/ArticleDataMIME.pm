# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Default::ArticleDataMIME;

use strict;
use warnings;

use parent qw( Kernel::System::Search::Object::Base );
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Main',
    'Kernel::System::Search',
);

=head1 NAME

Kernel::System::Search::Object::Default::ArticleDataMIME - common base backend functions for specified object

=head1 DESCRIPTION

This module defines schema and rules for specified object to be used
for fallback or separate engine.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $SearchArticleDataMIMEObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::ArticleDataMIME');

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
        "Kernel::System::Search::Object::Engine::$Self->{Engine}::ArticleDataMIME",
        Silent => 1,
    );

    return $Kernel::OM->Get("Kernel::System::Search::Object::Engine::$Self->{Engine}::ArticleDataMIME") if $Loaded;

    $Self->{Module} = "Kernel::System::Search::Object::Default::ArticleDataMIME";

    # specify base config for index
    $Self->{Config} = {
        IndexRealName => 'article_data_mime',    # index name on the engine/sql side
        IndexName     => 'ArticleDataMIME',      # index name on the api side
        Identifier    => 'ID',                   # column name that represents object id in the field mapping
    };

    # define schema for data
    my $FieldMapping = {
        ID => {
            ColumnName => 'id',
            Type       => 'Integer'
        },
        ArticleID => {
            ColumnName => 'article_id',
            Type       => 'Integer'
        },
        From => {
            ColumnName => 'a_from',
            Type       => 'String'
        },
        ReplyTo => {
            ColumnName => 'a_reply_to',
            Type       => 'String'
        },
        To => {
            ColumnName => 'a_to',
            Type       => 'String'
        },
        CC => {
            ColumnName => 'a_cc',
            Type       => 'String'
        },
        BCC => {
            ColumnName => 'a_bcc',
            Type       => 'String'
        },
        Subject => {
            ColumnName => 'a_subject',
            Type       => 'String'
        },
        MessageID => {
            ColumnName => 'a_message_id',
            Type       => 'String'
        },
        MessageIDMD5 => {
            ColumnName => 'a_message_id_md5',
            Type       => 'String'
        },
        InReplyTo => {
            ColumnName => 'a_in_reply_to',
            Type       => 'String'
        },
        References => {
            ColumnName => 'a_references',
            Type       => 'String'
        },
        ContentType => {
            ColumnName => 'a_content_type',
            Type       => 'String'
        },
        Body => {
            ColumnName => 'a_body',
            Type       => 'Textarea'
        },
        IncomingTime => {
            ColumnName => 'incoming_time',
            Type       => 'Long'
        },
        ContentPath => {
            ColumnName => 'content_path',
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
