# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Admin::Node::ES;

use parent qw( Kernel::System::Search::Admin::Node );

use strict;
use warnings;

our @ObjectDependencies = ();

=head1 NAME

Kernel::System::Search::Admin::Node::ES - Node details elastic search backend functions

=head1 DESCRIPTION

TO-DO

=head1 PUBLIC INTERFACE

=head2 new()

    my $SearchAdminNodeESObject = $Kernel::OM->Get('Kernel::System::Search::Admin::Details::ES::NodeAdd');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

1;
