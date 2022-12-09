# --
# Copyright (C) 2012-2022 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Default::DynamicFieldObjIdName;

use strict;
use warnings;

use parent qw( Kernel::System::Search::Object::Base );
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Main',
    'Kernel::System::Search',
);

=head1 NAME

Kernel::System::Search::Object::Default::DynamicFieldObjIdName - common base backend functions for specified object

=head1 DESCRIPTION

This module defines schema and rules for specified object to be used
for fallback or separate engine.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $SearchDynamicFieldObjIdNameObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::DynamicFieldObjIdName');

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
        "Kernel::System::Search::Object::Engine::$Self->{Engine}::DynamicFieldObjIdName",
        Silent => 1,
    );

    return $Kernel::OM->Get("Kernel::System::Search::Object::Engine::$Self->{Engine}::DynamicFieldObjIdName")
        if $Loaded;

    $Self->{Module} = "Kernel::System::Search::Object::Default::DynamicFieldObjIdName";

    # specify base config for index
    $Self->{Config} = {
        IndexRealName => 'dynamic_field_obj_id_name',    # index name on the engine/sql side
        IndexName     => 'DynamicFieldObjIdName',        # index name on the api side
        Identifier    => 'ObjectID',                     # column name that represents object id in the field mapping
    };

    # define schema for data
    my $FieldMapping = {
        ObjectID => {
            ColumnName => 'object_id',
            Type       => 'Integer'
        },
        ObjectName => {
            ColumnName => 'object_name',
            Type       => 'String'
        },
        ObjectType => {
            ColumnName => 'object_type',
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
