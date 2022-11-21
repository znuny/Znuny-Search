# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Default::DynamicField;

use strict;
use warnings;

use parent qw( Kernel::System::Search::Object::Base );
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Main',
    'Kernel::System::Search',
);

=head1 NAME

Kernel::System::Search::Object::Default::DynamicField - common base backend functions for specified object

=head1 DESCRIPTION

This module defines schema and rules for specified object to be used
for fallback or separate engine.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $SearchDynamicFieldObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::DynamicField');

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
        "Kernel::System::Search::Object::Engine::$Self->{Engine}::DynamicField",
        Silent => 1,
    );

    return $Kernel::OM->Get("Kernel::System::Search::Object::Engine::$Self->{Engine}::DynamicField") if $Loaded;

    $Self->{Module} = "Kernel::System::Search::Object::Default::DynamicField";

    # specify base config for index
    $Self->{Config} = {
        IndexRealName => 'dynamic_field',    # index name on the engine/sql side
        IndexName     => 'DynamicField',     # index name on the api side
        Identifier    => 'ID',               # column name that represents object id in the field mapping
    };

    # define schema for data
    my $FieldMapping = {
        ID => {
            ColumnName => 'id',
            Type       => 'Integer'
        },
        InternalField => {
            ColumnName => 'internal_field',
            Type       => 'Integer'
        },
        Name => {
            ColumnName => 'name',
            Type       => 'String'
        },
        Label => {
            ColumnName => 'label',
            Type       => 'String'
        },
        FieldOrder => {
            ColumnName => 'field_order',
            Type       => 'Integer'
        },
        FieldType => {
            ColumnName => 'field_type',
            Type       => 'String'
        },
        ObjectType => {
            ColumnName => 'object_type',
            Type       => 'String'
        },
        Config => {
            ColumnName => 'config',
            Type       => 'String'
        },
        ValidID => {
            ColumnName => 'valid_id',
            Type       => 'Integer'
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
