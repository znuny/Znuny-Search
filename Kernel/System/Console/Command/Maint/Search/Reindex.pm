# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::Search::Reindex;

use strict;
use warnings;

use parent qw(Kernel::System::Console::BaseCommand);

use Kernel::System::VariableCheck qw(IsHashRefWithData IsArrayRefWithData);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Search',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Reindex all data for specified indexes. This includes deleting data at the beginning.');
    $Self->AddOption(
        Name        => 'Object',
        Description => "Use to specify which index to reindex.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
        Multiple    => 1,
    );

    return;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    $Self->{SearchObject} = $Kernel::OM->Get('Kernel::System::Search');

    if ( !$Self->{SearchObject} || $Self->{SearchObject}->{Error} ) {
        my $Message;
        if ( !$Self->{SearchObject}->{ConnectObject} ) {
            $Message = "Could not connect to the cluster. Exiting..";
        }
        else {
            $Message = "Errors occured. Exiting..";
        }
        $Self->Print("<red>$Message\n</red>");
        return $Self->ExitCodeError();
    }

    my $ObjectOption = $Self->GetOption('Object') // [];

    my @Objects;
    if ( IsArrayRefWithData($ObjectOption) ) {
        for my $Object ( @{$ObjectOption} ) {
            eval {
                my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::$Object");
                $IndexObject->{Index} = $Object;
                push @Objects, $IndexObject;
            };

            if ($@) {
                $Self->Print(
                    "Cannot load module: Kernel::System::Search::Object::$Object\n" .
                        "Error message: $@"
                );
                return $Self->ExitCodeError();
            }
        }
    }

    else {
        my $SearchConfig = $Self->{SearchObject}->{Config}->{RegisteredIndexes} // [];

        if ( !IsArrayRefWithData($SearchConfig) ) {
            $Self->Print("No index found in Loader::Search config.\n");
            return $Self->ExitCodeError();
        }

        for my $Object ( @{$SearchConfig} ) {
            eval {
                my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::$Object");
                $IndexObject->{Index} = $Object;
                push @Objects, $IndexObject;
            };

            if ($@) {
                $Self->Print("Cannot find module: Kernel::System::Search::Object::$Object\n");
                return $Self->ExitCodeError();
            }
        }
    }

    $Self->{Objects} = \@Objects;

    return 1;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my %IndexObjectStatus = map { $_->{Index} => { "Successfull" => 0 } } @{ $Self->{Objects} };

    OBJECT:
    for my $Object ( @{ $Self->{Objects} } ) {
        $Self->Print("<yellow>Reindexing: $Object->{Index}</yellow>\n");

        eval {
            my $ObjectIDs = $Object->ObjectListIDs();

            next OBJECT if !( IsArrayRefWithData($ObjectIDs) );

            # clear whole index to reindex it correctly
            $Self->{SearchObject}->IndexClear(
                Index => $Object->{Index}
            );

            for my $ObjectID ( @{$ObjectIDs} ) {
                my $Result = $Self->{SearchObject}->ObjectIndexAdd(
                    Index    => $Object->{Index},
                    ObjectID => $ObjectID,
                );
                push @{ $IndexObjectStatus{ $Object->{Index} }{ObjectFails} }, $ObjectID
                    if !$Result;
            }

            $Self->Print("<green>Done.</green>\n");
            $IndexObjectStatus{ $Object->{Index} }{Successfull} = 1;
        };
        if ($@) {
            $Self->Print($@);
        }
    }

    $Self->Print("\n<yellow>Summary:</yellow>");
    for my $Index ( sort keys %IndexObjectStatus ) {
        $Self->Print("\nIndex: $Index\n");

        $Self->Print("Status: ");
        if ( $IndexObjectStatus{$Index}{Successfull} ) {
            if ( IsArrayRefWithData( $IndexObjectStatus{$Index}{ObjectFails} ) ) {
                $Self->Print("<yellow>Success with object fails.\n</yellow>");
                $Self->Print(
                    "Failed objects count: " . scalar( @{ $IndexObjectStatus{$Index}{ObjectFails} } ) . "\n"
                );
                $Self->Print( "ObjectIDs failed: " . join( ",", @{ $IndexObjectStatus{$Index}{ObjectFails} } ) . "\n" );
            }
            else {
                $Self->Print("<green>Success.\n</green>");
            }
        }
        else {
            $Self->Print("<red>Failed.\n</red>");
        }
    }

    return $Self->ExitCodeOk();
}

1;
