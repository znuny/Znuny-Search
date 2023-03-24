# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Default::CustomerUser;

use strict;
use warnings;

use parent qw( Kernel::System::Search::Object::Base );
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Main',
    'Kernel::System::Search',
);

=head1 NAME

Kernel::System::Search::Object::Default::CustomerUser - common base backend functions for specified object

=head1 DESCRIPTION

This module defines schema and rules for specified object to be used
for fallback or separate engine.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $SearchCustomerUserObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::CustomerUser');

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
        "Kernel::System::Search::Object::Engine::$Self->{Engine}::CustomerUser",
        Silent => 1,
    );

    return $Kernel::OM->Get("Kernel::System::Search::Object::Engine::$Self->{Engine}::CustomerUser") if $Loaded;
    return $Self;
}

1;
