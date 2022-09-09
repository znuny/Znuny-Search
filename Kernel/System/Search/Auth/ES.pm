# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Auth::ES;

use strict;
use warnings;

use parent qw(Kernel::System::Search::Auth);

our @ObjectDependencies = ();

=head1 NAME

Kernel::System::Search::Auth::ES - search authorization lib

=head1 DESCRIPTION

Elastic search engine authorization related functions

=head1 PUBLIC INTERFACE

=head2 new()

my $SearchAuthESObject = $Kernel::OM->Get('Kernel::System::Search::Auth::ES');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

1;
