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
    'Kernel::System::Search::Object',
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

    $Self->AddOption(
        Name => 'Recreate',
        Description =>
            "Before reindexing delete and add all specified indexes again with default settings instead of clearing it's data.",
        Required => 0,
        HasValue => 0,
        Multiple => 0,
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

    return 1;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');

    my $Recreate     = $Self->GetOption('Recreate');
    my $ObjectOption = $Self->GetOption('Object');

    if ( !IsArrayRefWithData($ObjectOption) ) {
        @{$ObjectOption} = reverse keys %{ $Self->{SearchObject}->{Config}->{RegisteredIndexes} };
    }

    my %IndexObjectStatus = map { $_ => { "Successfull" => 0 } } @{$ObjectOption};

    my @Objects;
    if ( IsArrayRefWithData($ObjectOption) ) {
        OBJECT_LOAD:
        for my $IndexName ( @{$ObjectOption} ) {

            # check index validity on otrs side
            my $Result = $SearchChildObject->IndexIsValid(
                IndexName => $IndexName,
                RealName  => 0,
            );

            if ( !$Result ) {
                $Self->Print("<red>Index: $IndexName is not valid! Ignoring reindexation for that index.\n</red>");
                next OBJECT_LOAD;
            }

            my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::$IndexName");

            $IndexObject->{Index} = $IndexName;
            push @Objects, $IndexObject;
        }
    }

    else {
        my $RegisteredIndexes = $Self->{SearchObject}->{Config}->{RegisteredIndexes} // {};

        if ( !IsHashRefWithData($RegisteredIndexes) ) {
            $Self->Print("No index found in Loader::Search config.\n");
            return $Self->ExitCodeError();
        }

        for my $IndexName ( sort keys %{$RegisteredIndexes} ) {

            # check index validity on otrs side
            my $Result = $SearchChildObject->IndexIsValid(
                IndexName => $IndexName,
                RealName  => 0,
            );

            if ( !$Result ) {
                $Self->Print("<red>Index: $IndexName is not valid! Ignoring reindexation for that index.\n</red>");
                next OBJECT_LOAD;
            }

            my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::$IndexName");
            $IndexObject->{Index} = $IndexName;
            push @Objects, $IndexObject;
        }
    }

    # list all indexes on remote (engine) side
    my @ActiveClusterRemoteIndexList = $Self->{SearchObject}->IndexList();

    OBJECT:
    for my $Object (@Objects) {
        $Self->Print("<yellow>-----\n</yellow>");
        $Self->Print("<yellow>Reindexing: $Object->{Index}</yellow>\n");
        $Self->Print("<yellow>--\n</yellow>");

        # get real name index name from sysconfig
        my $IndexRealName = $Self->{SearchObject}->{Config}->{RegisteredIndexes}->{ $Object->{Index} };

        # check if real name index on remote side exists
        my $RemoteExists = grep { $_ eq $IndexRealName } @ActiveClusterRemoteIndexList;

        eval {
            EVAL_SCOPE: {
                my $ObjectIDs = $Object->ObjectListIDs(
                    OrderBy    => 'Down',
                    ResultType => 'ARRAY'
                );

                last EVAL_SCOPE if !( IsArrayRefWithData($ObjectIDs) );

                if ( !$RemoteExists ) {
                    my $SearchIndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::$Object->{Index}");
                    my $IndexRealName     = $SearchIndexObject->{Config}->{IndexRealName};

                    $Self->Print(
                        "<yellow>$Object->{Index} index is valid on otrs backend side, but does not exists on the search engine.\n"
                            .
                            "Index on engide side with real name: \"$IndexRealName\" as \"$Object->{Index}\" (friendly name on otrs side) will be created.\n\n</yellow>"
                    );

                    my $AddSuccess = $Self->{SearchObject}->IndexAdd(
                        IndexName            => $Object->{Index},
                        SetRoutingAllocation => 1,
                    );
                }
                elsif ($Recreate) {
                    my $RemoveSuccess = $Self->{SearchObject}->IndexRemove(
                        IndexName => $Object->{Index},
                    );

                    if ( !$RemoveSuccess ) {
                        $Self->Print(
                            "<red>Could not remove index: $Object->{Index}! Ignoring reindexation for that index.\n</red>"
                        );
                        last EVAL_SCOPE;
                    }

                    my $AddSuccess = $Self->{SearchObject}->IndexAdd(
                        IndexName            => $Object->{Index},
                        SetRoutingAllocation => 1,
                    );

                    if ( !$AddSuccess ) {
                        $Self->Print(
                            "<red>Could not add index: $Object->{Index}! Ignoring reindexation for that index.\n</red>"
                        );
                        last EVAL_SCOPE;
                    }
                    else {
                        $Self->Print("<green>Index recreated succesfully.\n</green>");
                    }

                }
                else {
                    # clear whole index to reindex it correctly
                    my $ClearSuccess = $Self->{SearchObject}->IndexClear(
                        Index => $Object->{Index}
                    );

                    if ( !$ClearSuccess ) {
                        $Self->Print(
                            "<red>Could not clear index: $Object->{Index} data! Ignoring reindexation for that index.\n</red>"
                        );
                        last EVAL_SCOPE;
                    }
                }

                # initialize index
                my $InitSuccess = $Self->{SearchObject}->IndexInit(
                    Index      => $Object->{Index},
                    SetAliases => 1,
                );

                if ( !$InitSuccess ) {
                    $Self->PrintError("Can't initialize index: $Object->{Index}!\n");
                    $IndexObjectStatus{ $Object->{Index} }{Successfull} = 0;
                    last EVAL_SCOPE;
                }

                $Self->Print("<green>Index initialized.</green>\n<yellow>Adding indexes..</yellow>\n");

                my $Count        = 0;
                my @ObjectIDsArr = @{$ObjectIDs};

                for my $ObjectID (@ObjectIDsArr) {
                    my $Result = $Self->{SearchObject}->ObjectIndexAdd(
                        Index    => $Object->{Index},
                        ObjectID => $ObjectID,
                        Refresh  => 0,
                    );

                    $Count++;

                    # show progress every 500 indexes
                    if ( $Count % 500 == 0 ) {
                        my $Percent = int( $Count / ( $#ObjectIDsArr / 100 ) );
                        $Self->Print(
                            "<yellow>$Count</yellow> of <yellow>$#ObjectIDsArr</yellow> processed (<yellow>$Percent %</yellow> done).\n"
                        );
                    }

                    push @{ $IndexObjectStatus{ $Object->{Index} }{ObjectFails} }, $ObjectID
                        if !$Result;
                }

                $Self->Print("<green>Done.</green>\n");
                $IndexObjectStatus{ $Object->{Index} }{Successfull} = 1;
            }
        };

        if ($@) {
            $Self->Print($@);
        }
    }

    $Self->Print("\n<yellow>Summary:</yellow>\n");
    if ( keys %IndexObjectStatus ) {
        for my $Index ( sort keys %IndexObjectStatus ) {
            $Self->Print("\nIndex: $Index\n");

            $Self->Print("Status: ");
            if ( $IndexObjectStatus{$Index}{Successfull} ) {
                if ( IsArrayRefWithData( $IndexObjectStatus{$Index}{ObjectFails} ) ) {
                    $Self->Print("<yellow>Success with object fails.\n</yellow>");
                    $Self->Print(
                        "Failed objects count: " . scalar( @{ $IndexObjectStatus{$Index}{ObjectFails} } ) . "\n"
                    );
                    $Self->Print(
                        "ObjectIDs failed: " . join( ",", @{ $IndexObjectStatus{$Index}{ObjectFails} } ) . "\n"
                    );
                }
                else {
                    $Self->Print("<green>Success.\n</green>");
                }
            }
            else {
                $Self->Print("<red>Failed.\n</red>");
            }
        }
    }
    else {
        $Self->Print("\n<yellow>No data to reindex found.</yellow>\n");
    }

    return $Self->ExitCodeOk();
}

1;
