# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Query::DynamicField;

use strict;
use warnings;

use parent qw( Kernel::System::Search::Object::Query );

our @ObjectDependencies = (
    'Kernel::System::Search::Object::Default::DynamicField',
);

=head1 NAME

Kernel::System::Search::Object::Query::DynamicField - Functions to build query for specified operations

=head1 DESCRIPTION

Common search engine query backend functions.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $QueryDynamicFieldObject = $Kernel::OM->Get('Kernel::System::Search::Object::Query::DynamicField');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};

    my $IndexObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::DynamicField');

    # get index specified fields
    for my $Property( qw(Fields SupportedOperators OperatorMapping DefaultSearchLimit
        SupportedResultTypes Config ExternalFields SearchableFields )) {
        $Self->{'Index' . $Property} = $IndexObject->{$Property};
    }

    bless( $Self, $Type );

    return $Self;
}

1;
