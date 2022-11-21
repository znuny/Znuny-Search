# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Extensions::Ticket::CustomPackage;

use strict;
use warnings;

our @ObjectDependencies = (
);

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # This will override original TicketID from "Kernel::System::Search::Object::Default::Ticket".
    my $FieldMapping = {
        TicketID => 'TicketID'
    };

    $Self->{Fields} = $FieldMapping;

    return $Self;
}

1;
