# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Operators::FullText::Engine::ES;

use strict;
use warnings;

our @ObjectDependencies = ();

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub QueryBuild {
    my ( $Self, %Param ) = @_;

    my %OperatorMapping = (
        'AND' => 'and',
        'OR'  => 'or'
    );

    my $Value;
    if ( ref $Param{Value} ne 'HASH' ) {
        $Value = {
            query    => $Param{Value},
            operator => $OperatorMapping{AND}
        };
    }
    else {
        $Value->{query}    = $Param{Value}->{Text};
        $Value->{operator} = $OperatorMapping{ $Param{Value}->{QueryOperator} || "AND" };
    }

    return {
        Query => {
            match => {
                $Param{Field} => $Value
            }
        },
        Section => 'must'
    };
}

1;
