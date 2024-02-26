# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Mapping::ES::FAQ;

use strict;
use warnings;
use MIME::Base64;

use parent qw( Kernel::System::Search::Mapping::ES );

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Encode',
);

=head1 NAME

Kernel::System::Search::Mapping::ES::FAQ - elastic search mapping lib

=head1 DESCRIPTION

Functions to map parameters from/to query/response to API functions.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $SearchMappingESFAQObject = $Kernel::OM->Get('Kernel::System::Search::Mapping::ES::FAQ');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=head2  _ResponseDataFormat()

globally formats response data from engine

    my $Result = $SearchMappingESFAQObject->_ResponseDataFormat(
        Result => $Result,
        QueryData => $QueryData,
    );

=cut

sub _ResponseDataFormat {
    my ( $Self, %Param ) = @_;

    my $Objects;
    my $SimpleArray = $Param{ResultType} && $Param{ResultType} eq 'ARRAY_SIMPLE' ? 1 : 0;
    my $SimpleHash  = $Param{ResultType} && $Param{ResultType} eq 'HASH_SIMPLE'  ? 1 : 0;

    my $EncodeObject = $Kernel::OM->Get('Kernel::System::Encode');

    if ( IsArrayRefWithData( $Param{Result}->{hits}->{hits} ) ) {
        my $Hits   = $Param{Result}->{hits}->{hits};
        my @Fields = keys %{ $Param{Fields} };

        # when specified fields are filtered response
        # contains them inside "fields" key
        if (
            $Param{QueryData}->{Query}->{Body}->{_source}
            && $Param{QueryData}->{Query}->{Body}->{_source} eq 'false'
            )
        {
            # filter scalar/array fields by return type
            my @ScalarFields;
            my @ArrayFields;

            # decide if simple format is needed
            # othwersie it will be an array of objects
            if ($SimpleArray) {
                for my $Hit ( @{$Hits} ) {
                    for my $Field ( @{ $Hit->{fields} } ) {
                        push @{$Objects}, $Hit->{fields}->{$Field};
                    }
                }
                return $Objects;
            }
            elsif ($SimpleHash) {
                for my $Hit ( @{$Hits} ) {
                    for my $Field ( sort keys %{ $Hit->{fields} } ) {
                        $Objects->{ $Hit->{fields}->{$Field}->[0] } = 1;
                    }
                }
                return $Objects;
            }
            else {
                @ScalarFields = grep { $Param{Fields}->{$_}->{ReturnType} !~ m{\AARRAY|HASH\z} } @Fields;
                @ArrayFields  = grep { $Param{Fields}->{$_}->{ReturnType} eq 'ARRAY' } @Fields;
            }

            for my $Hit ( @{$Hits} ) {
                my %Data;

                # get proper data for scalar/hash/arrays from response
                for my $Field (@ScalarFields) {
                    $Data{$Field} = $Hit->{fields}->{$Field}->[0];
                }

                for my $Field (@ArrayFields) {
                    $Data{$Field} = $Hit->{fields}->{$Field};
                }

                push @{$Objects}, \%Data;
            }
        }

        # ES engine response stores objects inside "_source" key by default
        elsif ( IsHashRefWithData( $Hits->[0]->{_source} ) || $Hits->[0]->{inner_hits} ) {
            if (
                IsArrayRefWithData( $Param{QueryData}->{Query}->{Body}->{_source} )
                &&
                grep { $_ eq 'Attachments.Content' } @{ $Param{QueryData}->{Query}->{Body}->{_source} }
                )
            {
                for my $Hit ( @{$Hits} ) {
                    my $Attachments = $Hit->{_source}->{Attachments};
                    if ( IsArrayRefWithData($Attachments) ) {
                        for ( my $i = 0; $i < scalar @{$Attachments}; $i++ ) {
                            my $Attachment = $Attachments->[$i];
                            if ( $Attachment->{Content} ) {
                                $Hit->{_source}->{Attachments}->[$i]->{Content}
                                    = decode_base64( $Attachment->{Content} );
                            }
                    
                        }
                    }
                    push @{$Objects}, $Hit->{_source};
                }
            }
            else {
                if ($SimpleArray) {
                    for my $Hit ( @{$Hits} ) {
                        for my $Field ( sort keys %{ $Hit->{_source} } ) {
                            push @{$Objects}, $Hit->{_source}->{$Field};
                        }
                    }
                }
                elsif ($SimpleHash) {
                    for my $Hit ( @{$Hits} ) {
                        if ( IsHashRefWithData( $Hit->{_source} ) ) {
                            for my $Value ( values %{ $Hit->{_source} } ) {
                                $Objects->{$Value} = 1;
                            }
                        }
                    }
                    return $Objects;
                }

                else {
                    for my $Hit ( @{$Hits} ) {
                        push @{$Objects}, $Hit->{_source};
                    }
                }
            }
        }
    }
    elsif ( IsArrayRefWithData( $Param{Result}->{rows} ) ) {
        for ( my $j = 0; $j < scalar @{ $Param{Result}->{rows} }; $j++ ) {
            my %Data;
            for ( my $i = 0; $i < scalar @{ $Param{Result}->{columns} }; $i++ ) {
                $Data{ $Param{Result}->{columns}->[$i]->{name} } = $Param{Result}->{rows}->[$j]->[$i];
            }
            push @{$Objects}, \%Data;
        }
    }

    return $Objects;
}

1;
