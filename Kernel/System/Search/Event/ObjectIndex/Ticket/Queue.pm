# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Event::ObjectIndex::Ticket::Queue;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Search',
);

sub new {
    my ( $Type, %Param ) = @_;

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

    my $OldGroupID = $Param{Data}->{OldQueue}->{GroupID};
    my $NewGroupID = $Param{Data}->{Queue}->{GroupID};

    # execute only on group change
    return 1 if $OldGroupID == $NewGroupID;

    my $QueueType = 'GroupIDChanged';

    $SearchChildObject->IndexObjectQueueAdd(
        Index => 'Ticket',
        Value => {
            FunctionName => 'ObjectIndexUpdate',
            $Param{Data}->{Queue}->{QueueID} . "_$QueueType" => {
                QueryParams  => {
                    QueueID => $Param{Data}->{OldQueue}->{QueueID},
                },
            },
            NewData => {
                GroupID => $NewGroupID,
            },
            QueueType => $QueueType,
        },
    );

    return 1;
}

1;
