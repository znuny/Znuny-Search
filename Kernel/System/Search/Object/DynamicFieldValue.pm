# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::DynamicFieldValue;

use strict;
use warnings;

use parent qw( Kernel::System::Search::Object::Base );
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Main',
    'Kernel::System::Search',
);

=head1 NAME

Kernel::System::Search::Object::DynamicFieldValue - common base backend functions for specified object

=head1 DESCRIPTION

This module defines schema and rules for specified object to be used
for fallback or separate engine.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $SearchDynamicFieldValueObject = $Kernel::OM->Get('Kernel::System::Search::Object::DynamicFieldValue');

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
        "Kernel::System::Search::Object::$Self->{Engine}::DynamicFieldValue",
        Silent => 1,
    );

    return $Kernel::OM->Get("Kernel::System::Search::Object::$Self->{Engine}::DynamicFieldValue") if $Loaded;

    $Self->{Module} = "Kernel::System::Search::Object::DynamicFieldValue";

    # specify base config for index
    $Self->{Config} = {
        IndexRealName => 'dynamic_field_value',    # index name on the engine/sql side
        IndexName     => 'DynamicFieldValue',      # index name on the api side
        Identifier    => 'ID',                     # column name that represents object id in the field mapping
    };

    # define schema for data
    my $FieldMapping = {
        ID => {
            ColumnName => 'id',
            Type       => 'Integer'
        },
        ObjectID => {
            ColumnName => 'object_id',
            Type       => 'Integer'
        },
        FieldID => {
            ColumnName => 'field_id',
            Type       => 'String'
        },
        Value => {
            ColumnName => 'value',
            Type       => 'String'
        },
    };

    $Self->{Config}->{AdditionalOTRSFields} = {
        ValueText => {
            ColumnName => 'value_text',
            Type       => 'String'
        },
        ValueDate => {
            ColumnName => 'value_date',
            Type       => 'String'
        },
        ValueInt => {
            ColumnName => 'value_int',
            Type       => 'String'
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
