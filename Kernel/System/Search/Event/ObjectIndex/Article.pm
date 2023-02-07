# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Event::ObjectIndex::Article;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Search',
    'Kernel::System::CommunicationChannel',
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

    NEEDED:
    for my $Needed (qw(FunctionName)) {
        next NEEDED if $Param{Config}->{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed in Config!"
        );
        return;
    }

    my $IndexName         = 'Article';
    my $IndexSearchObject = $Kernel::OM->Get("Kernel::System::Search::Object::Default::$IndexName");

    my $ObjectIdentifierColumn = $IndexSearchObject->{Config}->{Identifier};
    my $FunctionName           = $Param{Config}->{FunctionName};
    my $ObjectID               = $Param{Data}->{$ObjectIdentifierColumn};

    if ( $FunctionName eq 'ObjectIndexRemove' ) {

        # event didn't send ArticleID in data, but there is TicketID
        # in that case remove all articles from this ticket
        if ( !IsArrayRefWithData($ObjectID) && $Param{Data}->{TicketID} ) {
            $SearchChildObject->IndexObjectQueueAdd(
                Index => 'Article',
                Value => {
                    FunctionName => $FunctionName,
                    QueryParams  => {
                        TicketID => $Param{Data}->{TicketID},
                    },
                },
            );

        }

        # event specified article to delete, delete only this article
        elsif ( IsArrayRefWithData($ObjectID) || IsNumber($ObjectID) ) {
            $SearchChildObject->IndexObjectQueueAdd(
                Index => 'Article',
                Value => {
                    FunctionName => $FunctionName,
                    ObjectID     => $ObjectID,
                },
            );
        }

        return 1;
    }

    if ( $Param{Event} eq 'TicketMerge' ) {
        $SearchChildObject->IndexObjectQueueAdd(
            Index => 'Article',
            Value => {
                FunctionName => $FunctionName,
                QueryParams  => {
                    TicketID => $Param{Data}->{TicketID},
                },
            },
        );

        $SearchChildObject->IndexObjectQueueAdd(
            Index => 'Article',
            Value => {
                FunctionName => $FunctionName,
                QueryParams  => {
                    TicketID => $Param{Data}->{MainTicketID},
                },
            },
        );

        return 1;
    }

    $SearchChildObject->IndexObjectQueueAdd(
        Index => 'Article',
        Value => {
            FunctionName => $FunctionName,
            QueryParams  => {
                TicketID => $Param{Data}->{TicketID},
            },
        },
    );

    # update ticket that contains changed article
    $SearchChildObject->IndexObjectQueueAdd(
        Index => 'Ticket',
        Value => {
            FunctionName => 'ObjectIndexSet',
            ObjectID     => $Param{Data}->{TicketID},
        },
    );

    return 1;
}

1;
