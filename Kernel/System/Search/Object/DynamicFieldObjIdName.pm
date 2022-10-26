# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::DynamicFieldObjIdName;

use strict;
use warnings;

use parent qw( Kernel::System::Search::Object::Base );
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Search::Object',
);

=head1 NAME

Kernel::System::Search::Object::DynamicFieldObjIdName - common base backend functions for specified object

=head1 DESCRIPTION

This module defines schema and rules for specified object to be used
for fallback or separate engine.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $SearchDynamicFieldObjIdNameObject = $Kernel::OM->Get('Kernel::System::Search::Object::DynamicFieldObjIdName');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

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
    );

    return $Self;
}

1;
