# --
# Copyright (C) 2012-2022 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Default::ArticleDataMIMEAttachment;

use strict;
use warnings;

use parent qw( Kernel::System::Search::Object::Base );
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Search',
    'Kernel::System::Main',
);

=head1 NAME

Kernel::System::Search::Object::Default::ArticleDataMIMEAttachment - common base backend functions for specified object

=head1 DESCRIPTION

This module defines schema and rules for specified object to be used
for fallback or separate engine.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $SearchArticleDataMIMEObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::ArticleDataMIMEAttachment');

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
        "Kernel::System::Search::Object::Engine::$Self->{Engine}::ArticleDataMIMEAttachment",
        Silent => 1,
    );

    return $Kernel::OM->Get("Kernel::System::Search::Object::Engine::$Self->{Engine}::ArticleDataMIMEAttachment")
        if $Loaded;

    $Self->{Module} = "Kernel::System::Search::Object::Default::ArticleDataMIMEAttachment";

    # specify base config for index
    $Self->{Config} = {
        IndexRealName => 'article_data_mime_attachment',    # index name on the engine/sql side
        IndexName     => 'ArticleDataMIMEAttachment',       # index name on the api side
        Identifier    => 'ID',                              # column name that represents object id in the field mapping
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
        Filename => {
            ColumnName => 'filename',
            Type       => 'String'
        },
        ContentSize => {
            ColumnName => 'content_size',
            Type       => 'String'
        },
        ContentType => {
            ColumnName => 'content_type',
            Type       => 'String'
        },
        ContentID => {
            ColumnName => 'content_id',
            Type       => 'String'
        },
        ContentAlternative => {
            ColumnName => 'content_alternative',
            Type       => 'String'
        },
        Disposition => {
            ColumnName => 'disposition',
            Type       => 'String'
        },
        Content => {
            ColumnName => 'content',
            Type       => 'Blob'
        },
        CreateTime => {
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
        }
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
