# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Ticket;

use strict;
use warnings;

use parent qw( Kernel::System::Search::Object::Base );

our @ObjectDependencies = (
    'Kernel::System::Log',
);

=head1 NAME

Kernel::System::Search::Object::Ticket - common base backend functions for "Ticket" index

=head1 DESCRIPTION

TO-DO

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $SearchTicketObject = $Kernel::OM->Get('Kernel::System::Search::Object::Ticket ');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # Engine site "ticket" index unique key.
    $Self->{ResultFormat}->{Identifier} = 'TicketID';

    return $Self;
}

sub ResultFormat {
    my ( $Type, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    for my $Name (qw(Result Config Operation)) {
        if ( $Param{$Name} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return;
        }
    }

    # TODO further data standarization here and in Kernel::System::Search::Object::Base
    # Fallback response need to be same as reponse from this function!
    my $Objects = $Param{Objects};

    return $Objects;
}

1;
