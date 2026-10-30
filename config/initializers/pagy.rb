require "pagy/extras/gearbox"
require "pagy/extras/overflow"
Pagy::DEFAULT[:gearbox_items] = [10, 20, 50]
Pagy::DEFAULT[:overflow] = :last_page
