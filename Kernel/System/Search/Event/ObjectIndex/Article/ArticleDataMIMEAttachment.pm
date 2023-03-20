# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Event::ObjectIndex::Article::ArticleDataMIMEAttachment;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Search',
    'Kernel::Config',
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

    NEEDED:
    for my $Needed (qw(FunctionName)) {
        next NEEDED if $Param{Config}->{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed in Config!"
        );
        return;
    }

    my $ArticleStorageConfig = $ConfigObject->Get("Ticket::Article::Backend::MIMEBase::ArticleStorage");
    my $FunctionName         = $Param{Config}->{FunctionName};
    my $Success              = 1;

    if (
        $Param{Data}->{Disposition} && $Param{Data}->{Disposition} eq 'attachment'
        && $ArticleStorageConfig
        && $ArticleStorageConfig eq 'Kernel::System::Ticket::Article::Backend::MIMEBase::ArticleStorageDB'
        )
    {
        my $ArticleID = $Param{Data}->{ArticleID};
        $Success = $SearchChildObject->IndexObjectQueueAdd(
            Index => 'ArticleDataMIMEAttachment',
            Value => {
                FunctionName => $FunctionName,
                QueryParams  => {
                    ArticleID   => $ArticleID,
                    Disposition => 'attachment',
                },
                Context => "${FunctionName}_Attachment_ArticleID_$ArticleID",
            },
        );
    }

    return $Success;
}

1;
