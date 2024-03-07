# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Event::ObjectIndex::DynamicField;

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

    $Self->{SupportedDynamicFieldTypes} = {
        Ticket       => 1,
        Article      => 1,
        CustomerUser => 1,
    };

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

    my $FunctionName = $Param{Config}->{FunctionName};

    $SearchChildObject->IndexObjectQueueEntry(
        Index => 'DynamicField',
        Value => {
            Operation => $FunctionName,
            ObjectID  => $Param{Data}->{NewData}->{ID},
        },
    );

    my $FieldID = $Param{Data}->{NewData}->{ID};

    my $ObjectType = $Param{Data}->{NewData}->{ObjectType};

    return if ( !$Self->{SupportedDynamicFieldTypes}->{$ObjectType} );

    my $UpdateIndex;
    if ( $ObjectType eq 'Article' || $ObjectType eq 'Ticket' ) {
        $UpdateIndex = 'Ticket';
    }
    else {
        $UpdateIndex = $ObjectType;
    }
    my $Success = 1;

    if ( $Param{Event} eq 'DynamicFieldDelete' ) {
        my $OldDFName = $Param{Data}->{NewData}->{Name};

        $Success = $SearchChildObject->IndexObjectQueueEntry(
            Index => $UpdateIndex,
            Value => {
                Operation   => 'ObjectIndexUpdate',
                QueryParams => {},
                Data        => {
                    CustomFunction => {
                        Name   => 'ObjectIndexUpdateDFChanged',
                        Params => {
                            DynamicField => {
                                ObjectType => $ObjectType,
                                Name       => $OldDFName,
                                Event      => 'Remove',
                            }
                        },
                    }
                },
                Context => "ObjectIndexUpdate_DFDelete_${FieldID}",
            },
        );
        return $Success;
    }

    my $OldDFName = $Param{Data}->{OldData}->{Name};
    my $NewDFName = $Param{Data}->{NewData}->{Name};

    if ( $NewDFName && $OldDFName && $NewDFName ne $OldDFName ) {

        $Success = $SearchChildObject->IndexObjectQueueEntry(
            Index => $UpdateIndex,
            Value => {
                Operation   => 'ObjectIndexUpdate',
                QueryParams => {},
                Data        => {
                    CustomFunction => {
                        Name   => 'ObjectIndexUpdateDFChanged',
                        Params => {
                            DynamicField => {
                                ObjectType => $ObjectType,
                                Name       => $OldDFName,
                                NewName    => $Param{Data}->{NewData}->{Name},
                                Event      => 'NameChange',
                            }
                        },
                    },
                },
                Context => "ObjectIndexUpdate_DFNameChanged_${OldDFName}_${ObjectType}",
            },
        );
        return $Success;
    }

    return 1;
}

1;
