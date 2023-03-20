# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Operators::Wildcard::Fallback::Default;

use Kernel::System::VariableCheck qw(:all);

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

    my @ParamValue = IsArrayRefWithData( $Param{Value} ) ? @{ $Param{Value} } : ( $Param{Value} );

    # get like escape string needed for some databases (e.g. oracle)
    my $LikeEscapeString = $DBObject->GetDatabaseFunction('LikeEscapeString');

    my $Query = '';
    my @Binds;

    my $ApplyOR;
    for my $Param (@ParamValue) {
        $Param =~ s/\*/%/g;
        $Query .= ' OR ' if $ApplyOR;
        $Query .= "$Param{Field} LIKE ?$LikeEscapeString";
        push @Binds, $Param;
        $ApplyOR = 1;
    }

    return {
        Query         => $Query,
        Bindable      => 1,
        BindableValue => [@Binds],
    };
}

1;
