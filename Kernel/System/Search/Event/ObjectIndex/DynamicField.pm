# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Event::ObjectIndex::DynamicField;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Search',
    'Kernel::System::Console::Command::Maint::Search::Reindex',
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
    for my $Needed (qw(FunctionName)) {
        if ( !$Param{Config}->{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed in Config!"
            );
            return;
        }
    }

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');

    return if $SearchObject->{Fallback};

    my $FunctionName = $Param{Config}->{FunctionName};

    # delete dynamic field definition from advanced search engine
    my $Result = $SearchObject->$FunctionName(
        Index    => 'DynamicField',
        ObjectID => $Param{Data}->{NewData}->{ID}
    );

    # deleting dynamic field definition triggers event
    # dynamic field delete but does not trigger dynamic field value delete
    # even when sql engine delete them
    # delete dynamic field with dynamic field value data from advanced engine
    if ( $FunctionName eq 'ObjectIndexRemove' ) {

        $SearchObject->ObjectIndexRemove(
            Index       => 'DynamicFieldValue',
            QueryParams => {
                FieldID => $Param{Data}->{NewData}->{ID}
            }
        );

        # TO-DO optimize
        $Self->_ReindexObject( Object => 'Ticket' );

    }
    elsif ( $FunctionName eq 'ObjectIndexSet' || $FunctionName eq 'ObjectIndexUpdate' ) {
        if ( $Param{Data}->{NewData}->{Name} && $Param{Data}->{OldData}->{Name} ) {
            my $DynamicFieldNameChanged = $Param{Data}->{NewData}->{Name} ne $Param{Data}->{OldData}->{Name};

            # trigger reindexing all tickets in case dynamic field name has been changed
            # TO-DO optimize
            if ($DynamicFieldNameChanged) {
                $Self->_ReindexObject( Object => 'Ticket' );
            }
        }
    }

    return 1;
}

sub _ReindexObject {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    for my $Name (qw(Object)) {
        if ( !$Param{$Name} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return;
        }
    }

    # execute command to reindex specified object
    my $CommandObject = $Kernel::OM->Get('Kernel::System::Console::Command::Maint::Search::Reindex');
    my @CommandArgs   = ( '--Object', $Param{Object}, '--Recreate', 'latest' );

    my $CommandOutput;
    {
        local *STDOUT;
        open STDOUT, '>:utf8', \$CommandOutput;    ## no critic
        $CommandObject->Execute(@CommandArgs);
    }

    if (
        $CommandOutput =~ /Success with object fails\.|Status\: Failed/
        &&
        $CommandOutput !~ /Status: Success\./
        )
    {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Could not reindex object: \"$Param{Object}\" correctly!"
        );
        return;
    }

    return 1;
}

1;
