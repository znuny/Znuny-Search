# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Event::ObjectIndex::TicketDelete;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Search',
    'Kernel::Config',
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicField::Backend',
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

    my $LogObject                 = $Kernel::OM->Get('Kernel::System::Log');
    my $DynamicFieldObject        = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
    my $SearchChildObject         = $Kernel::OM->Get('Kernel::System::Search::Object');
    my $ConfigObject              = $Kernel::OM->Get('Kernel::Config');

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

    my $TicketID = $Param{Data}->{TicketID};
    return 1 if !$TicketID;

    my %ValidIndexes;

    # ticket is an entity related to many indexes
    # all of those needs to be updated
    for my $Index (qw(Ticket Article)) {
        my $IsValid = $SearchChildObject->IndexIsValid(
            IndexName => $Index,
        );

        $ValidIndexes{$Index} = $IsValid;
    }

    if ( $ValidIndexes{Ticket} ) {
        $SearchChildObject->IndexObjectQueueEntry(
            Index => 'Ticket',
            Value => {
                Operation => 'ObjectIndexRemove',
                ObjectID  => $TicketID,
            },
        );
    }
    if ( $ValidIndexes{Article} ) {
        my $ArticleID = $Param{Data}->{ArticleID};

        # event didn't send ArticleID in data, but there is TicketID
        # in that case remove all articles from this ticket
        if ( !IsArrayRefWithData($ArticleID) && $TicketID ) {
            $SearchChildObject->IndexObjectQueueEntry(
                Index => 'Article',
                Value => {
                    Operation   => 'ObjectIndexRemove',
                    QueryParams => {
                        TicketID => $TicketID,
                    },
                    Context => "ObjectIndexRemove_TicketDelete_$TicketID",
                },
            );
        }

        # event specified article to delete, delete only this article
        elsif ( IsArrayRefWithData($ArticleID) || IsNumber($ArticleID) ) {
            $SearchChildObject->IndexObjectQueueEntry(
                Index => 'Article',
                Value => {
                    Operation => 'ObjectIndexRemove',
                    ObjectID  => $ArticleID,
                },
            );
        }
    }

    return 1;
}

1;
