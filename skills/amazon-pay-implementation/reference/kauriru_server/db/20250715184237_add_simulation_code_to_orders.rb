class AddSimulationCodeToOrders < ActiveRecord::Migration[6.1]
  def change
    add_column :orders, :simulation_code, :string, comment: 'Amazon Payシミュレーションコード'
  end
end
