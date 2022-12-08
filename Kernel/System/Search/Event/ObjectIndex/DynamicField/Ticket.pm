# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Event::ObjectIndex::DynamicField::Ticket;

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

    $Self->{AllowedDynamicFieldTypes} = {
        Ticket  => 1,
        Article => 1,
    };

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');
    return if $SearchObject->{Fallback};
    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(Data Event Config)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed!"
        );
        return;
    }

    # ticket index data will need to be set
    # on any dynamic field operation
    my $FunctionName = 'ObjectIndexSet';

    # check if updated dynamic field is of type Article
    my $PrependToField = '';
    my $ObjectType     = 'Ticket';
    if ( $Param{Data}->{NewData}->{ObjectType} ) {
        return 1 if !$Self->{AllowedDynamicFieldTypes}->{ $Param{Data}->{NewData}->{ObjectType} };

        if ( $Param{Data}->{NewData}->{ObjectType} eq 'Article' ) {
            $PrependToField .= 'Article_';
            $ObjectType = 'Article';
        }
    }

    my $EventData = {
        Data => {
            DynamicField => {
                $ObjectType => {
                    New => {
                        Name => $Param{Data}->{NewData}->{Name},
                    },
                    Old => {
                        Name => $Param{Data}->{OldData}->{Name},
                    }
                }
            }
        },
        Type => $Param{Config}->{Event},
    };

    if ( $Param{Config}->{Event} eq 'DynamicFieldDelete' ) {
        my $TicketIDs = $SearchObject->Search(
            Objects     => ['Ticket'],
            QueryParams => {
                $PrependToField . "DynamicField_$Param{Data}->{NewData}->{Name}" => {
                    Operator => "IS DEFINED"
                }
            },
            ResultType => 'HASH',
            Event      => $EventData,
        );

        my @TicketIDs = keys %{ $TicketIDs->{Ticket} };
        $SearchObject->$FunctionName(
            Index    => 'Ticket',
            ObjectID => \@TicketIDs,
        );

        return if !scalar @TicketIDs;
        return 1;
    }

    if ( $Param{Data}->{NewData}->{Name} && $Param{Data}->{OldData}->{Name} ) {
        my $DynamicFieldNameChanged = $Param{Data}->{NewData}->{Name} ne $Param{Data}->{OldData}->{Name};

        if ($DynamicFieldNameChanged) {
            my $TicketIDs = $SearchObject->Search(
                Objects     => ['Ticket'],
                QueryParams => {
                    $PrependToField . "DynamicField_$Param{Data}->{OldData}->{Name}" => {
                        Operator => "IS DEFINED"
                    }
                },
                ResultType => 'HASH',
                Event      => $EventData,
            );

            my @TicketIDs = keys %{ $TicketIDs->{Ticket} };
            return if !scalar @TicketIDs;

            $SearchObject->$FunctionName(
                Index    => 'Ticket',
                ObjectID => \@TicketIDs,
            );
        }
    }

    return 1;
}

1;
