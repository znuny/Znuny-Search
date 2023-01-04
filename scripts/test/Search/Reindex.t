# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));
use Kernel::System::VariableCheck qw(:all);

# this test is not supposed to be executed in gitlab ci

# get helper object
$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);

my $SearchObject       = $Kernel::OM->Get('Kernel::System::Search');
my $ReindexationObject = $Kernel::OM->Get('Kernel::System::Search::Admin::Reindexation');

# just for gitlab pipeline to pass this test
if ( !$SearchObject->{ConnectObject} ) {
    return 1;
}

# check if there is connection with search engine
$Self->True(
    $SearchObject->{ConnectObject},
    "Connection to engine - Exists"
);

my $RegisteredIndexes    = $SearchObject->{Config}->{RegisteredIndexes};
my $AnyIndexIsRegistered = IsHashRefWithData($RegisteredIndexes);

$Self->True(
    $AnyIndexIsRegistered,
    "Any index is registered for testing check."
);

if ($AnyIndexIsRegistered) {
    for my $Index ( sort keys %{$RegisteredIndexes} ) {
        my @Params = (
            '--index',    $Index,
            '--recreate', 'default',
            '--limit',    5,
        );

        # 0 is exit code that identify success of reindexation
        my $ExitCode = $ReindexationObject->StartReindexation(
            Params => \@Params,
        );

        $Self->False(
            $ExitCode,
            "Index reindexation test for $Index."
        );
    }
}

1;
