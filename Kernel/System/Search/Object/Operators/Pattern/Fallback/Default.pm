# --
# Copyright (C) 2012-2022 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Operators::Pattern::Fallback::Default;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::DB'
);

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub QueryBuild {
    my ( $Self, %Param ) = @_;

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    my %RegexpOpearator = (
        mysql      => "$Param{Field} REGEXP ?",
        postgresql => "$Param{Field} ~ ?",
        oracle     => "REGEXP_LIKE ($Param{Field}, ?)",
    );

    return {
        Query         => $RegexpOpearator{ $DBObject->{"DB::Type"} },
        Bindable      => 1,
        BindableValue => [ $Param{Value} ],
    };
}

1;
