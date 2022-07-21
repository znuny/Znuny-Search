# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::Search::IndexEvent::Ticket;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Search',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    # check needed stuff
    for my $Needed (qw(Data Event Config)) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }
    for my $Needed (qw(TicketID)) {
        if ( !$Param{Data}->{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed in Data!"
            );
            return;
        }
    }
    for my $Needed (qw(FunctionName)) {
        if ( !$Param{Config}->{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed in Data!"
            );
            return;
        }
    }

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');

    my %QueryParam = (
        Index    => "Ticket",
        ObjectID => $Param{Data}->{TicketID}
    );

    my $FunctionName = $Param{Config}->{FunctionName};

    # Prevent error code 500 when engine index failed.
    eval {
        my $Success = $SearchObject->$FunctionName(
            %QueryParam
        );

        if ( !$Success ) {

            #TODO handle not succesfull event operation
        }
    };
    if ($@) {
        $LogObject->Log(
            Priority => 'error',
            Message  => $@,
        );
    }

    return 1;
}

1;
