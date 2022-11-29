# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Event::ObjectIndex;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Search',
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

    my $IndexSearchObject = $Kernel::OM->Get("Kernel::System::Search::Object::Default::$Param{Config}->{IndexName}");
    my $ObjectIdentifierColumn = $IndexSearchObject->{Config}->{Identifier};

    if ( !$Param{Data}->{$ObjectIdentifierColumn} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Need ObjectID ($ObjectIdentifierColumn) in event Data!"
        );
        return;
    }

    my %QueryParam = (
        Index    => $Param{Config}->{IndexName},
        ObjectID => $Param{Data}->{$ObjectIdentifierColumn},
    );

    my $FunctionName = $Param{Config}->{FunctionName};

    $SearchObject->$FunctionName(
        %QueryParam,
        Refresh => 1,    # live indexing should be refreshed every time
    );

    return 1;
}

1;
