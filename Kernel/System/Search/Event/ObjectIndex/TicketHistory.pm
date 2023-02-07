# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Event::ObjectIndex::TicketHistory;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Search',
    'Kernel::System::Ticket',
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

    my $LogObject         = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');
    return if $SearchObject->{Fallback};

    NEEDED:
    for my $Needed (qw(Data Event Config)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed!"
        );
        return;
    }

    NEEDED:
    for my $Needed (qw(FunctionName)) {
        next NEEDED if $Param{Config}->{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed in Config!"
        );
        return;
    }

    my $FunctionName       = $Param{Config}->{FunctionName};
    my $TicketID           = $Param{Data}->{TicketID};
    my $MergedIntoTicketID = $Param{Data}->{MainTicketID};

    $SearchChildObject->IndexObjectQueueAdd(
        Index => 'TicketHistory',
        Value => {
            FunctionName => $FunctionName,
            QueryParams  => {
                TicketID => $TicketID,
            },
        },
    );

    $SearchChildObject->IndexObjectQueueAdd(
        Index => 'TicketHistory',
        Value => {
            FunctionName => $FunctionName,
            QueryParams  => {
                TicketID => $MergedIntoTicketID,
            },
        },
    ) if $MergedIntoTicketID;

    return 1;
}

1;
