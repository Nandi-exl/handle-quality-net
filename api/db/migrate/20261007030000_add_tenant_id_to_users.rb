# frozen_string_literal: true

# Each user belongs to exactly one organization (F-02).
# Like other tenant_id columns, this references public.organizations.id without
# a database foreign key, because that table is owned by an external system.
#
# Existing users are left unassigned (NULL) and cannot log in until an
# organization is assigned to them; the migration cannot guess it safely.
class AddTenantIdToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :tenant_id, :bigint
    add_index :users, :tenant_id
  end
end
