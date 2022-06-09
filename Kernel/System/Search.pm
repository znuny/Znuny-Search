# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsHashRefWithData);

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Search::Object',
    'Kernel::System::Main',
);

=head1 NAME

Kernel::System::Search - TO-DO

=head1 DESCRIPTION

TO-DO

=head1 PUBLIC INTERFACE


=head2 new()

TO-DO

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    $Self->{Config} = $Self->ConfigGet();    

    # Check if ElasticSearch feature is enabled.
    if ( !$Self->{Config}->{Enabled} ) {
        $Self->{Error} = 1;
    }

    my $ModulesCheckOk;

    # Check if there is choosen active engine of the search.
    if ( !$Self->{Config}->{ActiveEngine} && !$Self->{Error} ) {
        $Self->{Error} = 1;
        $LogObject->Log(
            Priority => 'error',
            Message  => "Search configuration does not specify a valid active engine!",
        );
    } else {
        $ModulesCheckOk = $Self->BaseModulesCheck(
            Config => $Self->{Config},
        );
    }

    if(!$ModulesCheckOk){
        $Self->{Error} = 1;
    }

    # If there were no errors before, try connecting.
    $Self->{ConnectObject} = $Self->Connect(
        Config => $Self->{Config},
    ) if !$Self->{Error};

    return $Self;
}

=head2 Search()

TO-DO

=cut

sub Search {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search::Object');
    NEEDED:
    for my $Needed (qw(Objects QueryParams)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Missing param: $Needed",
        );
        return;
    }

    # If there was an critical error, fallback all of the objects with given search parameters.
    if ( $Self->{Error} ) {
        my $Response = $SearchObject->Fallback(%Param);
        return $Response;
    }

    my $Result = $SearchObject->QueryPrepare(
        %Param,
        Operation => "Search",
    );

    if ( $Result->{Error} ) {
        $Result->{Fallback} = $Self->Fallback(%Param);
    }

#     return $Result if !$Result->{Fallback}->{Continue};

    my @Queries = $Result->{Queries} || ();

    my $QueriesToExecute = $Queries[0];

    my @Result;
    for my $Query ( @{$QueriesToExecute} ) {

        my $ResultQuery = $Self->{EngineObject}->QueryExecute(
            Query     => $Query,
            Index     => 'ticket',
            QueryType => 'search',
            ConnectObject => $Self->{ConnectObject},
        );

        push @Result, $ResultQuery;
    }

    # my $Response = {};

    # # TODO: Standarization of specific object response after claryfication of response from query execute.

    return \@Result;

}

=head2 Connect()

TO-DO

=cut

sub Connect {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    if ( !IsHashRefWithData $Param{Config} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need Config!"
        );
        return;
    }

    return if !$Self->{EngineObject}->can('Connect');
    my $ConnectObject = $Self->{EngineObject}->Connect(%Param);

    if(!$ConnectObject || $ConnectObject->{Failed}){
        $Self->{Error} = 1;
    }
    return $ConnectObject;
}

=head2 Disconnect()

TO-DO

=cut

sub Disconnect {
    my ( $Self, %Param ) = @_;

    return 1;
}

=head2 IndexAdd()

TO-DO

=cut

sub IndexAdd {
    my ( $Self, %Param ) = @_;

    return 1;
}

=head2 IndexDrop()

TO-DO

=cut

sub IndexDrop {
    my ( $Self, %Param ) = @_;

    return 1;
}

=head2 ConfigGet()

TO-DO

=cut

sub ConfigGet {
    my ( $Self, %Param ) = @_;

    # MOCK-UP
    my %Config = (
        ActiveEngine => "ES",
        Enabled => 1,
    );

    return \%Config;
}

=head2 BaseModulesCheck()

TO-DO

=cut

sub BaseModulesCheck {
    my ( $Self, %Param ) = @_;

    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');

    return if !$Param{Config}->{ActiveEngine};
    # define base modules
    my %Modules = (
        "Mapping" => "Kernel::System::Search::Mapping::$Param{Config}->{ActiveEngine}",
        "Engine"  => "Kernel::System::Search::Engine::$Param{Config}->{ActiveEngine}",
    );
    
    # check if base modules exists and add them to $Self
    for my $Module(keys %Modules){
        my $Location = $Modules{$Module};
        my $Loaded = $MainObject->Require(
            $Location,
            Silent => 1,                # optional, no log entry if module was not found
        );
        if(!$Loaded){
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Module $Location is not valid!"
            );
            return;
        } else {
            $Self->{$Module . "Object"} = $Kernel::OM->Get($Location);
        }
    }

    return 1;
}

1;
