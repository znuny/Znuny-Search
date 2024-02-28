# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --
## nofilter(TidyAll::Plugin::Znuny::CodeStyle::STDERRCheck)
## nofilter(TidyAll::Plugin::Znuny4OTRS::Legal::AGPLValidator)

package var::packagesetup::ZnunySearch;    ## no critic

use strict;
use warnings;

our @ObjectDependencies = (
);

=head1 NAME

var::packagesetup::ZnunySearch - code to execute during package installation

=head1 PUBLIC INTERFACE

=cut

=head2 new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $CodeObject = $Kernel::OM->Get('var::packagesetup::ZnunySearch');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=head2 CodeInstall()

run the code install part

    my $Result = $CodeObject->CodeInstall();

=cut

sub CodeInstall {
    my ( $Self, %Param ) = @_;

    return 1;
}

=head2 CodeUpgrade()

run the code upgrade part

    my $Result = $CodeObject->CodeUpgrade(
        PreVersion => '7.0.2',
    );

=cut

sub CodeUpgrade {
    my ( $Self, %Param ) = @_;

    my $SearchObject               = $Kernel::OM->Get('Kernel::System::Search');
    my $LogObject                  = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchESIngestPluginObject = $Kernel::OM->Get('Kernel::System::Search::Plugins::ES::Ingest');

    if ( $Param{PreVersion} && $Param{PreVersion} eq '7.0.2' ) {
        if (
            $SearchObject->{Config}->{ActiveEngine}
            &&
            $SearchObject->{Config}->{ActiveEngine} eq 'ES'        &&
            $SearchObject->{Config}->{RegisteredIndexes}->{Ticket} &&
            $SearchObject->{Config}->{RegisteredPlugins}->{Ingest} &&
            $SearchObject->{ConnectObject}
            )
        {
            my $Result     = $SearchESIngestPluginObject->ClusterInit();
            my $PluginName = $Result->{PluginName} || 'Ingest';

            # print in the same manner as other stuff is printed during CodeUpgrade,
            # look at Kernel::System::Package module
            if ( $Result->{Status}->{Success} ) {
                print STDERR "Notice: $PluginName plugin reinitialized succesfully\n";
            }
            else {
                print STDERR "Error: can't reinitialize $PluginName plugin!\n";
            }
        }
    }

    return 1;
}

=head2 CodeReinstall()

run the code reinstall part

    my $Result = $CodeObject->CodeReinstall();

=cut

sub CodeReinstall {
    my ( $Self, %Param ) = @_;

    return 1;
}

=head2 CodeUninstall()

run the code uninstall part

    my $Result = $CodeObject->CodeUninstall();

=cut

sub CodeUninstall {
    my ( $Self, %Param ) = @_;

    return 1;
}

1;
