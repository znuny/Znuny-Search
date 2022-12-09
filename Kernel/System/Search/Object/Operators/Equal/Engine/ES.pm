# --
# Copyright (C) 2012-2022 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Operators::Equal::Engine::ES;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

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

    # if expected response is an array, then search by arrays
    if ( $Param{ReturnType} && $Param{ReturnType} eq 'ARRAY' ) {
        if ( IsArrayRefWithData( $Param{Value}->[0] ) ) {
            my $Query;
            for my $Values ( @{ $Param{Value} } ) {
                push @{ $Query->{bool}->{should} }, {
                    terms_set => {
                        $Param{Field} . '.keyword' => {
                            terms                       => $Values,
                            minimum_should_match_script => {
                                source => "Math.max(params.num_terms, doc['$Param{Field}.keyword'].size())"
                            }
                        }
                    }
                };
            }
            return {
                Query   => $Query,
                Section => 'must'
            };
        }
        else {
            return {
                Query => {
                    terms_set => {
                        $Param{Field} . '.keyword' => {
                            terms                       => $Param{Value},
                            minimum_should_match_script => {
                                source => "Math.max(params.num_terms, doc['$Param{Field}.keyword'].size())"
                            }
                        }
                    }
                },
                Section => 'must'
            };
        }
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
