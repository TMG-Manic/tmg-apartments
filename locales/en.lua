local Translations = {
    error = {
        to_far_from_door = 'You are too far away from the Doorbell.',
        nobody_home = 'There is nobody home...',
        nobody_at_door = 'There is nobody at the door...',
        max_tenants = 'You have reached the maximum number of tenants.',
        insufficient_funds = 'You lack the funds for this upgrade.',
        not_owner = 'Only the property owner can modify keys or upgrades.'
    },
    success = {
        receive_apart = 'You acquired an apartment.',
        changed_apart = 'You successfully moved apartments.',
        key_given = 'You handed over a spare key.',
        key_revoked = 'You revoked a tenant\'s access.',
        upgraded = 'Apartment successfully upgraded to: '
    },
    info = {
        at_the_door = 'Someone is at the door!',
        current_tier = 'Current Tier: ',
    },
    text = {
        options = '[E] Apartment Options',
        enter = 'Enter Apartment',
        ring_doorbell = 'Ring Doorbell',
        logout = 'Sleep (Logout)',
        change_outfit = 'Wardrobe',
        open_stash = 'Open Stash',
        move_here = 'Purchase / Move Here',
        open_door = 'Buzz In (Open Door)',
        leave = 'Leave Apartment',
        close_menu = 'Close Interface',
        tennants = 'Intercom: Tenants',
        -- New Features
        manage_keys = 'Manage Keys',
        give_key = 'Provide Key to ID',
        revoke_key = 'Revoke Key',
        upgrade_apart = 'Renovate / Upgrade'
    }
}

Lang = Lang or Locale:new({
    phrases = Translations,
    warnOnMissing = true
})