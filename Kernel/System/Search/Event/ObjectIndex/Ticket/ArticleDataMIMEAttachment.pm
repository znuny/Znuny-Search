# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Event::ObjectIndex::Ticket::ArticleDataMIMEAttachment;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Search',
    'Kernel::System::Search::Plugins::ES::Ingest',
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
    my $ConfigObject      = $Kernel::OM->Get('Kernel::Config');

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

    # TicketID was denormalized into the attachment data
    # so it can be deleted based on this param
    my $ArticleStorageConfig = $ConfigObject->Get("Ticket::Article::Backend::MIMEBase::ArticleStorage");
    my $Success              = 1;

    if (
        $ArticleStorageConfig
        &&
        $ArticleStorageConfig eq 'Kernel::System::Ticket::Article::Backend::MIMEBase::ArticleStorageDB'
        )
    {
        if ( $Param{Event} eq 'TicketDelete' ) {
            my $TicketID = $Param{Data}->{TicketID};

            $Success = $SearchChildObject->IndexObjectQueueAdd(
                Index => 'ArticleDataMIMEAttachment',
                Value => {
                    FunctionName => 'ObjectIndexRemove',
                    QueryParams  => {
                        TicketID => $TicketID,
                    },
                },
            );
        }
    }

    return $Success;
}

1;
