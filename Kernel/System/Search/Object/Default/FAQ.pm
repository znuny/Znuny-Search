# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Default::FAQ;

use strict;
use warnings;

use parent qw( Kernel::System::Search::Object::Base );

our @ObjectDependencies = (
    'Kernel::System::Main',
    'Kernel::System::Search',
);

=head1 NAME

Kernel::System::Search::Object::Default::FAQ - common base backend functions for specified object

=head1 DESCRIPTION

This module defines schema and rules for specified object to be used
for fallback or separate engine.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $SearchFAQObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::FAQ');

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
        "Kernel::System::Search::Object::Engine::$Self->{Engine}::FAQ",
        Silent => 1,
    );

    return $Kernel::OM->Get("Kernel::System::Search::Object::Engine::$Self->{Engine}::FAQ") if $Loaded;

    $Self->{Module} = "Kernel::System::Search::Object::Default::FAQ";

    # specify base config for index
    $Self->{Config} = {
        IndexRealName        => 'faq_item',    # index name on the engine/sql side
        IndexName            => 'FAQ',         # index name on the api side
        Identifier           => 'ID',          # column name that represents object id in the field mapping
        ChangeTimeColumnName => 'Changed',     # column representing time of updated data entry
    };

    # load settings for index
    $Self->{Config}->{Settings} = $Self->LoadSettings(
        IndexName => $Self->{Config}->{IndexName},
    );

    # define schema for data
    my $FieldMapping = {
        ID => {
            ColumnName => 'id',
            Type       => 'Integer'
        },
        Number => {
            ColumnName => 'f_number',
            Type       => 'Long'
        },
        Title => {
            ColumnName => 'f_subject',
            Type       => 'String'
        },
        Name => {
            ColumnName => 'f_name',
            Type       => 'String'
        },
        LanguageID => {
            ColumnName => 'f_language_id',
            Type       => 'Integer'
        },
        StateID => {
            ColumnName => 'state_id',
            Type       => 'Integer'
        },
        CategoryID => {
            ColumnName => 'category_id',
            Type       => 'Integer'
        },
        Approved => {
            ColumnName => 'approved',
            Type       => 'Integer'
        },
        ValidID => {
            ColumnName => 'valid_id',
            Type       => 'Integer'
        },
        ContentType => {
            ColumnName => 'content_type',
            Type       => 'String'
        },
        Keywords => {
            ColumnName => 'f_keywords',
            Type       => 'Textarea'
        },
        Field1 => {
            ColumnName => 'f_field1',
            Type       => 'Textarea'
        },
        Field2 => {
            ColumnName => 'f_field2',
            Type       => 'Textarea'
        },
        Field3 => {
            ColumnName => 'f_field3',
            Type       => 'Textarea'
        },
        Field4 => {
            ColumnName => 'f_field4',
            Type       => 'Textarea'
        },
        Field5 => {
            ColumnName => 'f_field5',
            Type       => 'Textarea'
        },
        Field6 => {
            ColumnName => 'f_field6',
            Type       => 'Textarea'
        },
        Created => {
            ColumnName => 'created',
            Type       => 'Date'
        },
        CreatedBy => {
            ColumnName => 'create_by',
            Type       => 'Integer'
        },
        Changed => {
            ColumnName => 'change_time',
            Type       => 'Date'
        },
        ChangedBy => {
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
