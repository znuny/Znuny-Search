# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
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

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    return if $SearchObject->{Fallback};
    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    # check needed parameters
    for my $Needed (qw(Data Event Config)) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }
    for my $Needed (qw(FunctionName IndexName)) {
        if ( !$Param{Config}->{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed in Config!"
            );
            return;
        }
    }

    my $TicketHistoryObject = $Kernel::OM->Get("Kernel::System::Search::Object::$Param{Config}->{IndexName}");
    my $FunctionName        = $Param{Config}->{FunctionName};
    my $TicketID            = $Param{Data}->{TicketID};

    my $Result;

    if ( $FunctionName eq 'ObjectIndexRemove' ) {
        eval {
            $SearchObject->$FunctionName(
                Index       => $Param{Config}->{IndexName},
                QueryParams => {
                    TicketID => $TicketID
                },
                Refresh => 1,    # live indexing should be refreshed every time
            );
        };
        if ($@) {
            $LogObject->Log(
                Priority => 'error',
                Message  => $@,
            );
        }

        return 1;
    }
    elsif ( $Param{Config}->{FunctionName} eq 'ObjectIndexUpdate' ) {

        my $TicketHistoryData = $SearchObject->Search(
            Objects     => ["TicketHistory"],
            QueryParams => {
                TicketID  => $TicketID,
                ArticleID => {
                    Operator => "!=",
                    Value    => 0,
                },
                ResultType => 'ARRAY',
                SortBy     => ["Changed"],
                OrderBy    => "Down",
            },
            Fields => [ ["TicketHistoryID"] ]
        );

        delete $TicketHistoryData->{TicketHistory}[-1];

        my %QueryParam;
        if ( IsArrayRefWithData( $TicketHistoryData->{TicketHistory} ) ) {
            TICKET_HISTORY:
            for my $TicketHistory ( @{ $TicketHistoryData->{TicketHistory} } ) {

                next TICKET_HISTORY if !$TicketHistory;

                %QueryParam = (
                    Index    => $Param{Config}->{IndexName},
                    ObjectID => $TicketHistory->{TicketHistoryID},
                );

                # prevent error code 500 when engine index failed
                eval {
                    $SearchObject->$FunctionName(
                        %QueryParam,
                        Refresh => 1,    # live indexing should be refreshed every time
                    );
                };
                if ($@) {
                    $LogObject->Log(
                        Priority => 'error',
                        Message  => $@,
                    );
                }
            }
        }

        return 1;
    }

    $Result = $TicketHistoryObject->SQLObjectSearch(
        QueryParams => {
            TicketID => $TicketID,
            CreateBy => $Param{UserID},
        },
        ResultType => 'ARRAY',
        SortBy     => "TicketHistoryID",
        OrderBy    => "DESC",
    );

    return if !IsArrayRefWithData($Result);

    my %QueryParam = (
        Index    => $Param{Config}->{IndexName},
        ObjectID => @{$Result}[0]->{id},
    );

    # prevent error code 500 when engine index failed
    eval {
        $SearchObject->$FunctionName(
            %QueryParam,
            Refresh => 1,    # live indexing should be refreshed every time
        );
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
