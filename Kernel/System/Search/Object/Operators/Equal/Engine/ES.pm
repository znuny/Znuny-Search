# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Operators::Equal::Engine::ES;

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

    if ( ref $Param{Value} ne "ARRAY" ) {
        $Param{Value} = [ $Param{Value} ];
    }

    my $Keyword = '';

    # _id is reserved in elastic search as identifier of documents
    # this can't get keyword if we want to search by it
    if ( $Param{Field} ne '_id' ) {
        $Keyword = '.keyword';
    }

    return {
        Query => {
            terms => {
                $Param{Field} . $Keyword => $Param{Value}
            }
        },
        Section => 'must'
    };
}

1;
