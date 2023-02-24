# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
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
    'Kernel::System::Search::Object',
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

    my $Success = 1;

    if ( $Param{Event} eq 'DynamicFieldDelete' ) {
        my $OldDFName = $Param{Data}->{NewData}->{Name};

        $Success = $SearchChildObject->IndexObjectQueueAdd(
            Index => 'Ticket',
            Value => {
                FunctionName         => 'ObjectIndexUpdate',
                QueryParams          => {},
                AdditionalParameters => {
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
                Context => "ObjUpdate_DFDeleted__${OldDFName}_${ObjectType}",
            },
        );
        return $Success;
    }

    my $OldDFName = $Param{Data}->{OldData}->{Name};
    my $NewDFName = $Param{Data}->{NewData}->{Name};

    if ( $NewDFName && $OldDFName && $NewDFName ne $OldDFName ) {
        $Success = $SearchChildObject->IndexObjectQueueAdd(
            Index => 'Ticket',
            Value => {
                FunctionName   => 'ObjectIndexUpdate',
                QueryParams    => {},
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
                Context => "ObjUpdate_DFNameChanged_${OldDFName}_${ObjectType}",
            },
        );
        return $Success;
    }

    return $Success;
}

1;
