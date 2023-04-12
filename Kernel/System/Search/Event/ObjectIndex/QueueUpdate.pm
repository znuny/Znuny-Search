# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Event::ObjectIndex::QueueUpdate;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Search',
    'Kernel::System::Search::Object',
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

    my $IsValid = $SearchChildObject->IndexIsValid(
        IndexName => 'Ticket',
    );

    return if !$IsValid;

    my $OldGroupID = $Param{Data}->{OldQueue}->{GroupID};
    my $NewGroupID = $Param{Data}->{Queue}->{GroupID};

    # execute only on group change
    return 1 if $OldGroupID == $NewGroupID;

    my $OldQueueID = $Param{Data}->{OldQueue}->{QueueID};

    $SearchChildObject->IndexObjectQueueEntry(
        Index => 'Ticket',
        Value => {
            Operation   => 'ObjectIndexUpdate',
            QueryParams => {
                QueueID => $OldQueueID,
            },
            Data => {
                CustomFunction => {
                    Name   => 'ObjectIndexUpdateGroupID',
                    Params => {
                        NewGroupID => $NewGroupID,
                    }
                },
            },
            Context => "ObjectIndexUpdate_GroupChange_${OldQueueID}_${NewGroupID}",
        },
    );

    return 1;
}

1;
