module Excel
  class Application
    def initialize
      WIN32OLE.ole_initialize

      @application = WIN32OLE.new 'Excel.Application'
    end

    def add template = nil
      if template.nil?
        WorkBook.new @application.WorkBooks.Add
      else
        if File.file? template
          WorkBook.new @application.WorkBooks.Add(File.expand_path(template).gsub('/', '\\'))
        else
          nil
        end
      end
    end

    def open file
      if File.file? file
        WorkBook.new @application.WorkBooks.Open(File.expand_path(file).gsub('/', '\\'))
      else
        nil
      end
    end

    def quit
      begin
        @application.Quit
        @application.ole_free
      rescue
      end

      @application = nil
      GC.start
    end

    def self.excel? file
      ['.xls', '.xlsx'].include? File.extname(file).downcase
    end
  end

  class WorkBook
    def initialize workbook
      @workbook = workbook
    end

    def worksheet index = 1
      WorkSheet.new @workbook.WorkSheets(index)
    end

    def save file = nil
      if file.nil?
        @workbook.Save
      else
        if not Application.excel? file
          if @workbook.application.Version.to_i > 11
            file += '.xlsx'
          else
            file += '.xls'
          end
        end

        if File.file? file
          File.delete file
        end

        @workbook.SaveAs File.expand_path(file).gsub('/', '\\')
      end
    end

    def close save = false
      @workbook.Close save
    end
  end

  class WorkSheet
    attr_reader :worksheet

    def initialize worksheet
      @worksheet = worksheet
    end

    def data
      data = []

      @worksheet.UsedRange.Rows.Count.times do |i|
        line_data = []

        @worksheet.UsedRange.Columns.Count.times do |j|
          line_data << get(i + 1, j + 1)
        end

        data << line_data
      end

      data
    end

    private

    def get row, col
      @worksheet.Cells(row, col).Value.to_s.utf8.strip
    end

    def set row, col, val
      @worksheet.Cells(row, col).Value = val.to_s.locale
    end
  end
end