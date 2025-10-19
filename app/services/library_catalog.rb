class LibraryCatalog
  class << self
    def sections
      LibraryClass.includes(:library_sessions).all
    end
  end
end
