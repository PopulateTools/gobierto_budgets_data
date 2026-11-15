# frozen_string_literal: true

# Postgres database with the tables of the Ministerio de Hacienda budgets
# (tb_inventario_<year>, tb_economica_<year>, tb_funcional_<year>), filled by each test.
module BudgetsDatabase
  NAME = ENV.fetch("BUDGETS_TEST_DATABASE", "gobierto_budgets_data_test")

  def self.connection
    @connection ||= begin
      create_database
      ActiveRecord::Base.establish_connection(adapter: "postgresql", database: NAME)
      ActiveRecord::Base.connection
    end
  end

  def self.create_database
    ActiveRecord::Base.establish_connection(adapter: "postgresql", database: "postgres")
    existing = ActiveRecord::Base.connection.select_value("SELECT 1 FROM pg_database WHERE datname = #{ActiveRecord::Base.connection.quote(NAME)}")
    ActiveRecord::Base.connection.create_database(NAME) unless existing
    ActiveRecord::Base.remove_connection
  end

  def self.create_tables(year, inventory:, economic: [], functional: [], economic_amount_columns: %w(importe))
    economic_columns = economic_amount_columns.map { |column| "#{column} numeric(15,2)" }.join(", ")

    connection.execute(<<~SQL)
      DROP TABLE IF EXISTS tb_inventario_#{year}, tb_economica_#{year}, tb_funcional_#{year};
      CREATE TABLE tb_inventario_#{year} (idente numeric(15,2), codente varchar(10));
      CREATE TABLE tb_economica_#{year} (idente numeric(15,2), tipreig varchar(1), cdcta varchar(6), #{economic_columns});
      CREATE TABLE tb_funcional_#{year} (idente numeric(15,2), cdfgr varchar(6), cdcta varchar(6), importe numeric(15,2));
    SQL

    insert(connection, "tb_inventario_#{year}", inventory)
    insert(connection, "tb_economica_#{year}", economic)
    insert(connection, "tb_funcional_#{year}", functional)
  end

  def self.insert(connection, table, rows)
    rows.each do |row|
      values = row.values.map { |value| connection.quote(value) }.join(", ")
      connection.execute("INSERT INTO #{table} (#{row.keys.join(", ")}) VALUES (#{values})")
    end
  end
end
