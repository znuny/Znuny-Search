# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::Search::ES::AttachmentContent;

use strict;
use warnings;

use parent qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DB',
    'Kernel::System::Search',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description(
        'Use to trigger rebuild ticket attribute containing readable attachment content.'
    );

    return;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    $Self->{SearchObject} = $Kernel::OM->Get('Kernel::System::Search');

    if ( !$Self->{SearchObject} || $Self->{SearchObject}->{Error} ) {
        my $Message = "Errors occured. Exiting.";
        if ( !$Self->{SearchObject}->{ConnectObject} ) {
            $Message = "Could not connect to the cluster.";
        }
        $Self->Print("<red>$Message\n</red>");
        $Self->{Abort} = 1;
        return;
    }

    return 1;
}

sub Run {
    my ( $Self, %Param ) = @_;

    return $Self->ExitCodeError() if ( $Self->{Abort} );
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    $DBObject->Prepare(
        SQL => "SELECT ticket_id FROM es_attachment_content"
    );

    my %TicketIDs;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $TicketIDs{ $Row[0] } = 1;
    }

    my @TicketIDs = keys %TicketIDs;

    my $RebuildedTicketCount = {
        Success => 0,
        Failed  => 0,
    };

    if ( scalar @TicketIDs > 0 ) {
        my $Result = $Self->{SearchObject}->ObjectIndexSet(
            Index    => "Ticket",
            ObjectID => \@TicketIDs
        );

        $Result ? $RebuildedTicketCount->{Success}++ : $RebuildedTicketCount->{Failed}++;
    }

    $Self->Print(
        "<green>$RebuildedTicketCount->{Success} Ticket(s) attachments content was rebuilded for Elasticsearch.</green>\n"
    );
    if ( $RebuildedTicketCount->{Failed} ) {
        $Self->Print(
            "<red>$RebuildedTicketCount->{Failed} Ticket(s) attachments  content rebuilding failed for Elasticsearch.</red>\n"
        );
    }

    $DBObject->Prepare(
        SQL => "DELETE FROM es_attachment_content"
    );

    return $Self->ExitCodeOk();
}

1;
