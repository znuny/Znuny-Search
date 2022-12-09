# --
# Copyright (C) 2012-2022 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Admin::Details::ES;

use strict;
use warnings;

use parent qw( Kernel::System::Search::Admin::Details );

our @ObjectDependencies = ();

=head1 NAME

Kernel::System::Search::Admin::Details::ES - admin details for ES engine lib

=head1 DESCRIPTION

Cluster details elastic search backend functions.

=head1 PUBLIC INTERFACE

=head2 new()

    my $SearchAdminDetailsESObject = $Kernel::OM->Get('Kernel::System::Search::Admin::Details::ES');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

1;
